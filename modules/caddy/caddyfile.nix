{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.caddy;
  integration = import ../authentik/lib.nix {inherit lib;};
  inherit (integration) identityHeaders;
  inherit (lib) concatLists concatMapStrings optional optionalString;

  indent = level: text: let
    prefix = lib.concatStrings (lib.genList (_: " ") (level * 2));
    body = lib.removeSuffix "\n" text;
  in
    optionalString (body != "") (
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

  authBlock = route:
    if route.auth == "oauth"
    then let
      matcher = "role-${builtins.substring 0 12 (builtins.hashString "sha256" "${route.path}:${route.role}")}";
    in "import authentik-auth ${route.role} ${matcher}\n"
    else if route.auth == "basic"
    then
      renderBlock "basic_auth" ''
        {$WEB_USER} {$BASIC_AUTH_HASH}
      ''
    else if route.auth == null
    then ""
    else throw "Unsupported Caddy route auth: ${route.auth}";

  proxyTransport = endpoint:
    optionalString (endpoint.scheme == "https") (renderBlock "transport http" "tls_insecure_skip_verify\n");

  headerLines = endpoint:
    concatMapStrings (header: "header_up ${header}\n") endpoint.headerUp
    + concatMapStrings (header: "header_up -${header}\n") identityHeaders
    + optionalString endpoint.spoofBasic "header_up Authorization \"Basic {$BASIC_AUTH_HEADER}\"\n";

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

  renderPathEndpoint = endpoint: ''
    redir ${endpoint.path} ${endpoint.path}/

    ${renderBlock "route ${endpoint.path}*" (authBlock endpoint
      + optionalString (endpoint.type == "share" || endpoint.stripPrefix || endpoint.handlePath) "uri strip_prefix ${endpoint.path}\n"
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

  renderSecurityHeaders = renderBlock "header" ''
    Strict-Transport-Security "max-age=31536000; includeSubDomains"
    X-Content-Type-Options nosniff
    X-Frame-Options SAMEORIGIN
    Referrer-Policy no-referrer-when-downgrade
  '';

  renderRedirect = redirect:
    renderBlock "route /" "redir / ${redirect}\n";

  renderAuthRoute = renderBlock "route /outpost.goauthentik.io/*" "reverse_proxy ${integration.upstream}\n";

  # The second argument keeps role matchers unique across paths in a site.
  authentikAuth = renderBlock "(authentik-auth)" (concatMapStrings (header: "request_header -${header}\n") identityHeaders
    + renderBlock "forward_auth ${integration.upstream}" ''
      uri /outpost.goauthentik.io/auth/caddy
      copy_headers X-Authentik-Groups
    ''
    + renderBlock "@{args[1]}" ''
      not header_regexp X-Authentik-Groups `(^|\|){args[0]}(\||$)`
    ''
    + "respond @{args[1]} 403\n");

  renderTls = domain:
    if domain.tls == "public"
    then "import public-tls\n"
    else if domain.tls == "tailscale"
    then renderBlock "tls" "get_certificate tailscale\n"
    else throw "Unsupported Caddy site TLS mode: ${domain.tls}";

  renderDomain = site: domain: let
    endpoints = lib.sort (a: b: lib.stringLength a.path > lib.stringLength b.path) (lib.attrValues site.endpoints);
    hasOauth = integration.siteHasForwardAuth site;
    siteAddress = integration.domainAddress domain;
  in
    renderBlock siteAddress (
      optionalString site.log renderLog
      + optionalString site.securityHeaders renderSecurityHeaders
      + optionalString (site.redirect != null) (renderRedirect site.redirect)
      + optionalString hasOauth renderAuthRoute
      + concatMapStrings renderEndpoint endpoints
      + optionalString site.notFound "import not-found\n"
      + "\n"
      + renderTls domain
    )
    + "\n";

  renderSite = site: concatMapStrings (renderDomain site) site.domains;

  publicTls = renderBlock "(public-tls)" "tls /certs/fullchain.pem /certs/key.pem\n";

  notFoundHtml = builtins.readFile ./assets/404.html;

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
    renderGlobalBlock "email ${cfg.email}\n"
    + "\n"
    + publicTls
    + "\n"
    + notFound
    + "\n"
    + authentikAuth
    + "\n"
    + wildcardSite
    + "\n"
    + concatMapStrings renderSite (lib.attrValues cfg.sites)
  );

  endpointRows = lib.flatten (lib.mapAttrsToList (siteName: site:
    lib.mapAttrsToList (endpointName: endpoint: {
      inherit endpoint endpointName siteName;
    })
    site.endpoints)
  cfg.sites);

  domainRows = lib.flatten (lib.mapAttrsToList (siteName: site:
    map (domain: {
      inherit domain siteName;
    })
    site.domains)
  cfg.sites);

  domainKey = row: "${row.domain.host}:${toString (
    if row.domain.listenPort == null
    then 443
    else row.domain.listenPort
  )}";

  routeSummary = pkgs.writeText "caddy-routes.md" (''
      # Caddy Routes

      | Site | Endpoint | Path | Auth | Role | Upstream |
      | --- | --- | --- | --- | --- | --- |
    ''
    + concatMapStrings (row: let
      upstream =
        if row.endpoint.host == null || row.endpoint.port == null
        then "-"
        else "${row.endpoint.scheme}://${row.endpoint.host}:${toString row.endpoint.port}";
      role =
        if row.endpoint.role == null
        then "-"
        else row.endpoint.role;
      auth =
        if row.endpoint.auth == null
        then "none"
        else row.endpoint.auth;
    in "| ${row.siteName} | ${row.endpointName} | `${row.endpoint.path}` | ${auth} | ${role} | `${upstream}` |\n")
    endpointRows);

  routeAssertions = let
    mkAssertion = assertion: message: {inherit assertion message;};
    duplicatePaths = concatLists (lib.mapAttrsToList (siteName: site: let
      paths = map (endpoint: endpoint.path) (lib.attrValues site.endpoints);
    in
      optional (lib.length paths != lib.length (lib.unique paths)) siteName)
    cfg.sites);
    duplicateDomains = let
      keys = map domainKey domainRows;
    in
      lib.length keys != lib.length (lib.unique keys);
  in
    concatLists [
      (map (row:
        mkAssertion (lib.hasPrefix "/" row.endpoint.path) "Caddy endpoint ${row.siteName}.${row.endpointName} path must start with '/'.")
      endpointRows)
      (map (row:
        mkAssertion (row.endpoint.type != "proxy" || (row.endpoint.host != null && row.endpoint.port != null)) "Caddy proxy endpoint ${row.siteName}.${row.endpointName} must set host and port.")
      endpointRows)
      (map (row:
        mkAssertion (row.endpoint.type != "share" || (row.endpoint.host == null && row.endpoint.port == null)) "Caddy share endpoint ${row.siteName}.${row.endpointName} must not set host or port.")
      endpointRows)
      (map (row:
        mkAssertion (row.endpoint.auth != "oauth" || row.endpoint.role != null) "Caddy OAuth endpoint ${row.siteName}.${row.endpointName} must set role.")
      endpointRows)
      (map (row:
        mkAssertion (row.endpoint.auth != "oauth" || lib.elem row.endpoint.role config.authentik.roles) "Caddy OAuth endpoint ${row.siteName}.${row.endpointName} uses undeclared role '${row.endpoint.role}'.")
      endpointRows)
      (map (siteName:
        mkAssertion false "Caddy site '${siteName}' has duplicate endpoint paths.")
      duplicatePaths)
      [
        (mkAssertion (! duplicateDomains) "Caddy sites contain duplicate domain/listen-port combinations.")
        (mkAssertion (config.authentik.enable || lib.all (row: row.endpoint.auth != "oauth") endpointRows) "Caddy OAuth endpoints require authentik.enable.")
      ]
    ];
in {
  config = lib.mkIf cfg.enable {
    assertions = routeAssertions;

    caddy = {
      sites.media = {
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

      inherit caddyfile routeSummary;
    };

    environment.etc."caddy/routes.md".source = routeSummary;
  };
}
