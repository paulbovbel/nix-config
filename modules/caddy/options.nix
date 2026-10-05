{lib, ...}: let
  endpointType = lib.types.submodule ({
    name,
    config,
    ...
  }: {
    options = {
      type = lib.mkOption {
        type = lib.types.enum ["proxy" "share"];
        description = "Endpoint handler type.";
      };
      auth = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum ["oauth" "basic"]);
        default = "oauth";
        description = "Authentication method, or null to disable authentication.";
      };
      role = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Role required to access this endpoint.";
      };
      path = lib.mkOption {
        type = lib.types.str;
        description = "Request path matched by this endpoint.";
      };
      host = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Upstream host for a proxy endpoint.";
      };
      port = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
        description = "Upstream port for a proxy endpoint.";
      };
      scheme = lib.mkOption {
        type = lib.types.enum ["http" "https"];
        default = "http";
        description = "Upstream protocol for a proxy endpoint.";
      };
      stripPrefix = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to strip the matched path prefix before proxying.";
      };
      handlePath = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to strip the matched path prefix after authentication, equivalent to handle_path for the upstream.";
      };
      spoofBasic = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to derive an upstream basic authorization header from the authenticated user.";
      };
      headerUp = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional header_up directive arguments passed to Caddy.";
      };
      dashboard = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Show this endpoint in the Authentik application dashboard.";
        };
        name = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Application dashboard display name.";
        };
        iconUrl = lib.mkOption {
          type = lib.types.str;
          default = (import ./icons.nix {inherit lib;}) config.dashboard.iconName;
          description = "Application dashboard icon URL; defaults to Homarr SVG/PNG lookup.";
        };
        iconName = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Homarr icon name; light artwork is preferred for dark backgrounds.";
        };
      };
    };
  });

  domainType = lib.types.submodule {
    options = {
      host = lib.mkOption {
        type = lib.types.str;
        description = "Hostname served by this domain.";
      };
      listenPort = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
        description = "Explicit port on which Caddy listens for this domain.";
      };
      tls = lib.mkOption {
        type = lib.types.enum ["public" "tailscale"];
        default = "public";
        description = "TLS certificate source for this domain.";
      };
    };
  };

  siteType = lib.types.submodule {
    options = {
      domains = lib.mkOption {
        type = lib.types.listOf domainType;
        default = [];
        description = "Domains that expose this site.";
      };
      endpoints = lib.mkOption {
        type = lib.types.attrsOf endpointType;
        default = {};
        description = "Site endpoints keyed by logical name.";
      };
      redirect = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Target to which the site root redirects.";
      };
      log = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to enable Caddy access logging for this site.";
      };
      securityHeaders = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to add the standard security response headers.";
      };
      notFound = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether unmatched requests receive a not-found response.";
      };
    };
  };
in {
  options.caddy = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable containerized Caddy proxy and auth.";
    };

    share.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable share endpoint.";
    };

    email = lib.mkOption {
      type = lib.types.str;
      default = "paul@bovbel.com";
      description = "Contact email for NixOS-managed ACME certificates.";
    };

    sites = lib.mkOption {
      type = lib.types.attrsOf siteType;
      default = {};
      example = {
        media = {
          domains = [{host = "media.example.com";}];
          endpoints.app = {
            type = "proxy";
            path = "/";
            host = "media";
            port = 8080;
            role = "admin";
          };
        };
      };
      description = "Caddy sites keyed by logical service name.";
    };

    caddyfile = lib.mkOption {
      type = lib.types.package;
      description = "Rendered Caddyfile template derivation.";
    };

    routeSummary = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "Markdown summary of configured Caddy sites and endpoints.";
    };
  };
}
