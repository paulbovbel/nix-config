{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.caddy;

  indent = level: text: let
    prefix = lib.concatStrings (lib.genList (_: " ") (level * 2));
    body = lib.removeSuffix "\n" text;
  in
    lib.optionalString (body != "") (
      lib.concatStringsSep "\n" (map (line:
        if line == ""
        then ""
        else prefix + line) (lib.splitString "\n" body))
      + "\n"
    );

  renderBlock = header: body: ''
    ${header} {
    ${indent 1 body}}
  '';

  renderGlobalBlock = body: ''
    {
    ${indent 1 body}}
  '';

  renderUser = user:
    renderBlock "transform user" (''
        match realm google
        match email ${user.email}
      ''
      + lib.concatMapStrings (role: "action add role authp/${role}\n") user.roles);

  authBlock = route:
    if route.auth == "oauth"
    then "authorize with ${route.role}\n"
    else if route.auth == "basic"
    then
      renderBlock "basicauth" ''
        {$WEB_USER} {$BASIC_AUTH_HASH}
      ''
    else if route.auth == null
    then ""
    else throw "Unsupported Caddy route auth: ${route.auth}";

  proxyTransport = endpoint:
    lib.optionalString (endpoint.scheme == "https") (renderBlock "transport http" "tls_insecure_skip_verify\n");

  headerLines = endpoint:
    lib.concatMapStrings (header: "header_up ${header}\n") endpoint.headerUp
    + lib.optionalString endpoint.spoofBasic "header_up +Authorization \"Basic {$BASIC_AUTH_HEADER}\"\n";

  reverseProxy = endpoint:
    renderBlock "reverse_proxy * ${endpoint.scheme}://${endpoint.host}:${toString endpoint.port}" (proxyTransport endpoint + headerLines endpoint);

  renderRootEndpoint = endpoint:
    renderBlock "route *" (authBlock endpoint
      + (
        if endpoint.type == "proxy"
        then reverseProxy endpoint
        else throw "Unsupported root Caddy endpoint type: ${endpoint.type}"
      ));

  renderShareEndpoint = endpoint:
    "root * ${endpoint.path}\n"
    + renderBlock "file_server" ''
      browse
      hide .*
    '';

  renderPathEndpoint = endpoint:
    if endpoint.type == "proxy" && endpoint.handlePath
    then ''
      redir ${endpoint.path} ${endpoint.path}/

      ${renderBlock "handle_path ${endpoint.path}*" (authBlock endpoint + reverseProxy endpoint)}
    ''
    else ''
      redir ${endpoint.path} ${endpoint.path}/

      ${renderBlock "route ${endpoint.path}*" (authBlock endpoint
        + lib.optionalString (endpoint.type == "share" || endpoint.stripPrefix) "uri strip_prefix ${endpoint.path}\n"
        + (
          if endpoint.type == "proxy"
          then reverseProxy endpoint
          else if endpoint.type == "share"
          then renderShareEndpoint endpoint
          else throw "Unsupported Caddy endpoint type: ${endpoint.type}"
        ))}
    '';

  renderEndpoint = endpoint:
    if endpoint.path == "/"
    then renderRootEndpoint endpoint
    else renderPathEndpoint endpoint;

  renderLog = renderBlock "log" (
    "level INFO\n"
    + renderBlock "format console" "time_format wall\n"
  );

  renderRedirect = redirect:
    renderBlock "route /" "redir / ${redirect}\n";

  renderAuthRoute = renderBlock "route /auth*" "authenticate with defaultportal\n";

  renderTls = domain:
    if domain.tls == "public"
    then "import public-tls\n"
    else if domain.tls == "tailscale"
    then renderBlock "tls" "get_certificate tailscale\n"
    else throw "Unsupported Caddy site TLS mode: ${domain.tls}";

  renderDomain = site: domain: let
    endpoints = lib.sort (a: b: lib.stringLength a.path > lib.stringLength b.path) (lib.attrValues site.endpoints);
    hasOauth = lib.any (endpoint: endpoint.auth == "oauth") endpoints;
    siteAddress =
      if domain.listenPort == null
      then domain.host
      else "${domain.host}:${toString domain.listenPort}";
  in
    renderBlock siteAddress (
      lib.optionalString site.log renderLog
      + lib.optionalString (site.redirect != null) (renderRedirect site.redirect)
      + lib.optionalString hasOauth renderAuthRoute
      + lib.concatMapStrings renderEndpoint endpoints
      + lib.optionalString site.notFound "import not-found\n"
      + "\n"
      + renderTls domain
    )
    + "\n";

  renderSite = site: lib.concatMapStrings (renderDomain site) site.domains;

  renderSecurity = renderBlock "security" (
    renderBlock "oauth identity provider google" ''
      realm google
      driver google
      client_id {$GOOGLE_OAUTH2_CLIENT_ID}
      client_secret {$GOOGLE_OAUTH2_CLIENT_SECRET}
      scopes openid email profile
    ''
    + "\n"
    + renderBlock "authentication portal defaultportal" (''
        crypto default token lifetime 7884000
        crypto key sign-verify {$CADDY_TOKEN_SECRET}
        enable identity provider google
        cookie lifetime 7884000

      ''
      + lib.concatMapStrings renderUser cfg.users)
    + "\n"
    + lib.concatMapStrings (role:
      renderBlock "authorization policy ${role}" ''
        set auth url /auth/oauth2/google
        crypto key verify {$CADDY_TOKEN_SECRET}
        allow roles authp/${role}
        validate bearer header
        inject headers with claims
        enable js redirect
      '')
    cfg.roles
  );

  publicTls = renderBlock "(public-tls)" (renderBlock "tls" (''
      propagation_delay 60s
      propagation_timeout 5m
    ''
    + renderBlock "dns route53" ''
      access_key_id "{$AWS_ACCESS_KEY_ID}"
      secret_access_key "{$AWS_SECRET_ACCESS_KEY}"
      region "{$AWS_REGION}"
      hosted_zone_id "{$AWS_HOSTED_ZONE}"
    ''));

  notFoundHtml = builtins.readFile ./404.html;

  notFound = renderBlock "(not-found)" (renderBlock "route" (''
      header Content-Type text/html
      respond <<HTML
    ''
    + indent 1 notFoundHtml
    + "HTML 404\n"));

  wildcardSite = renderBlock "*.${config.networking.domain}" ''
    import not-found

    import public-tls
  '';

  caddyfile = pkgs.writeText "Caddyfile.template" (
    renderGlobalBlock (''
        email paul@bovbel.com

        order authenticate before respond
        order authorize before basicauth

      ''
      + renderSecurity)
    + "\n"
    + publicTls
    + "\n"
    + notFound
    + "\n"
    + wildcardSite
    + "\n"
    + lib.concatMapStrings renderSite (lib.attrValues cfg.sites)
  );
in {
  config = lib.mkIf config.caddy.enable {
    caddy.sites.media = {
      domains = [
        {
          host = "${config.networking.hostName}.${config.networking.domain}";
        }
        {
          host = "${config.networking.hostName}.${config.tailscale.domain}";
          tls = "tailscale";
        }
      ];
      log = true;
    };

    caddy.caddyfile = caddyfile;
  };
}
