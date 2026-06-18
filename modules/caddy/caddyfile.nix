{
  config,
  lib,
  pkgs,
  tailscaleDomain,
  ...
}: let
  cfg = config.caddy;
  primarySubdomain =
    if cfg.primarySubdomain != null
    then cfg.primarySubdomain
    else config.networking.hostName;
  primaryDomain = "${primarySubdomain}.${cfg.publicDomain}";
  endpoints = lib.sort (a: b: lib.stringLength a.path > lib.stringLength b.path) (lib.attrValues cfg.endpoints);

  renderUser = user: ''
          transform user {
            match realm google
            match email ${user.email}
    ${lib.concatMapStrings (role: ''
        action add role authp/${role}
      '')
      user.roles}
          }
  '';

  authBlock = endpoint:
    if endpoint.auth == "oauth"
    then "    authorize with ${endpoint.role}\n"
    else if endpoint.auth == "basic"
    then ''
      basicauth {
        {$WEB_USER} {$BASIC_AUTH_HASH}
      }
    ''
    else if endpoint.auth == null
    then ""
    else throw "Unsupported Caddy endpoint auth: ${endpoint.auth}";

  proxyTransport = endpoint:
    lib.optionalString (endpoint.scheme == "https") ''
      transport http {
        tls_insecure_skip_verify
      }
    '';

  headerLines = endpoint:
    lib.concatMapStrings (header: "        header_up ${header}\n") endpoint.headerUp
    + lib.optionalString endpoint.spoofBasic ''
      header_up +Authorization "Basic {$BASIC_AUTH_HEADER}"
    '';

  reverseProxy = endpoint: ''
        reverse_proxy * ${endpoint.scheme}://${endpoint.host}:${toString endpoint.port} {
    ${proxyTransport endpoint}${headerLines endpoint}    }
  '';

  renderEndpoint = endpoint:
    if endpoint.type == "proxy" && endpoint.handlePath
    then ''
        redir ${endpoint.path} ${endpoint.path}/

        handle_path ${endpoint.path}* {
      ${authBlock endpoint}${reverseProxy endpoint}  }

    ''
    else ''
        redir ${endpoint.path} ${endpoint.path}/

        route ${endpoint.path}* {
      ${authBlock endpoint}${lib.optionalString (endpoint.type == "share" || endpoint.stripPrefix) "    uri strip_prefix ${endpoint.path}\n"}
      ${
        if endpoint.type == "proxy"
        then reverseProxy endpoint
        else if endpoint.type == "share"
        then ''
          root * ${endpoint.path}
          file_server {
            browse
            hide .*
          }
        ''
        else ''
          ${throw "Unsupported Caddy endpoint type: ${endpoint.type}"}
        ''
      }
        }

    '';

  authDomainBlock = domainCfg:
    if domainCfg.auth == "oauth"
    then
      if domainCfg.role == null
      then throw "caddy.domains.<name>.role must be set when auth is oauth"
      else "    authorize with ${domainCfg.role}\n"
    else if domainCfg.auth == "basic"
    then ''
      basicauth {
        {$WEB_USER} {$BASIC_AUTH_HASH}
      }
    ''
    else if domainCfg.auth == null
    then ""
    else throw "Unsupported Caddy domain auth: ${domainCfg.auth}";

  renderDomain = domain: domainCfg: ''
    ${domain} {
      ${authDomainBlock domainCfg}reverse_proxy ${domainCfg.host}:${toString domainCfg.port}

      import public-tls
    }

  '';

  caddyfile = pkgs.writeText "Caddyfile.template" ''
      {
        email paul@bovbel.com

        order authenticate before respond
        order authorize before basicauth

        security {
          oauth identity provider google {
            realm google
            driver google
            client_id {$GOOGLE_OAUTH2_CLIENT_ID}
            client_secret {$GOOGLE_OAUTH2_CLIENT_SECRET}
            scopes openid email profile
          }

          authentication portal defaultportal {
            crypto default token lifetime 7884000
            crypto key sign-verify {$CADDY_TOKEN_SECRET}
            enable identity provider google
            cookie lifetime 7884000

      ${lib.concatMapStrings renderUser cfg.users}
          }

      ${lib.concatMapStrings (role: ''
        authorization policy ${role} {
          set auth url /auth/oauth2/google
          crypto key verify {$CADDY_TOKEN_SECRET}
          allow roles authp/${role}
          validate bearer header
          inject headers with claims
          enable js redirect
        }
      '')
      cfg.roles}
        }
      }

    (public-tls) {
      tls {
        propagation_delay 60s
        propagation_timeout 5m
        dns route53 {
          access_key_id "{$AWS_ACCESS_KEY_ID}"
            secret_access_key "{$AWS_SECRET_ACCESS_KEY}"
            region "{$AWS_REGION}"
            hosted_zone_id "{$AWS_HOSTED_ZONE}"
          }
        }
      }

    *.${cfg.publicDomain} {
      import public-tls
    }

    (primary-site) {
        log {
          level INFO
          format console {
            time_format wall
          }
        }

        ${lib.optionalString (cfg.redirect != null) ''
      route / {
        redir / ${cfg.redirect}
      }
    ''}
        route /auth* {
          authenticate with defaultportal
        }

    ${lib.concatMapStrings renderEndpoint endpoints}}

      ${primaryDomain} {
        import primary-site

        import public-tls
      }

      ${primarySubdomain}.${tailscaleDomain} {
        import primary-site

        tls {
          get_certificate tailscale
        }
      }

      ${lib.concatStringsSep "\n" (lib.mapAttrsToList renderDomain cfg.domains)}
  '';
in {
  config = lib.mkIf config.caddy.enable {
    caddy.caddyfile = caddyfile;
  };
}
