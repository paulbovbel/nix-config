{lib, ...}: let
  endpointType = lib.types.submodule {
    options = {
      type = lib.mkOption {type = lib.types.enum ["proxy" "share"];};
      auth = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum ["oauth" "basic"]);
        default = "oauth";
      };
      role = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      path = lib.mkOption {type = lib.types.str;};
      host = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      port = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
      };
      scheme = lib.mkOption {
        type = lib.types.enum ["http" "https"];
        default = "http";
      };
      stripPrefix = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      handlePath = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      spoofBasic = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      headerUp = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
    };
  };
  domainType = lib.types.submodule {
    options = {
      auth = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum ["oauth" "basic"]);
        default = "oauth";
        description = "Authentication mode for this domain proxy.";
      };

      role = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Authorization policy role required when auth is oauth.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Host to reverse proxy to for this domain.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        description = "Port to reverse proxy to for this domain.";
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

    redirect = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };

    publicDomain = lib.mkOption {
      type = lib.types.str;
      description = "Base public domain used for wildcard certificate selection.";
    };

    primarySubdomain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Primary public subdomain for the Caddy media site.";
    };

    share.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable share endpoint.";
    };

    roles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["admin" "share"];
    };

    users = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          email = lib.mkOption {type = lib.types.str;};
          roles = lib.mkOption {type = lib.types.listOf lib.types.str;};
        };
      });
      default = [];
    };

    endpoints = lib.mkOption {
      type = lib.types.attrsOf endpointType;
      default = {};
      description = "Caddy endpoints declared by service fragments.";
    };

    domains = lib.mkOption {
      type = lib.types.attrsOf domainType;
      default = {};
      description = "Additional public domains proxied to local host ports.";
    };

    caddyfile = lib.mkOption {
      type = lib.types.package;
      description = "Rendered Caddyfile template derivation.";
    };
  };
}
