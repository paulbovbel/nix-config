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
      host = lib.mkOption {type = lib.types.str;};
      listenPort = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
      };
      tls = lib.mkOption {
        type = lib.types.enum ["public" "tailscale"];
        default = "public";
      };
    };
  };

  siteType = lib.types.submodule {
    options = {
      domains = lib.mkOption {
        type = lib.types.listOf domainType;
        default = [];
      };
      endpoints = lib.mkOption {
        type = lib.types.attrsOf endpointType;
        default = {};
      };
      redirect = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      log = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      securityHeaders = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      notFound = lib.mkOption {
        type = lib.types.bool;
        default = true;
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

    email = lib.mkOption {
      type = lib.types.str;
      default = "paul@bovbel.com";
      description = "ACME contact email for Caddy.";
    };

    tokenLifetime = lib.mkOption {
      type = lib.types.ints.positive;
      default = 7884000;
      description = "OAuth token lifetime in seconds.";
    };

    cookieLifetime = lib.mkOption {
      type = lib.types.ints.positive;
      default = 7884000;
      description = "OAuth cookie lifetime in seconds.";
    };

    sites = lib.mkOption {
      type = lib.types.attrsOf siteType;
      default = {};
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
