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
in {
  options.caddy = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable containerized Caddy proxy and auth.";
    };

    redirect = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "/cockpit/";
    };

    components.share.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable share component.";
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

    caddyfile = lib.mkOption {
      type = lib.types.package;
      description = "Rendered Caddyfile template derivation.";
    };
  };
}
