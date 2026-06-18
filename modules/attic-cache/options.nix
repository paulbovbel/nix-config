{lib, ...}: {
  options.atticCache = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Attic binary cache server.";
    };

    subdomain = lib.mkOption {
      type = lib.types.str;
      default = "nix-cache";
      description = "Public subdomain used for the Attic cache endpoint.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Local atticd listen port.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/attic";
      description = "Attic server state directory.";
    };

    serverName = lib.mkOption {
      type = lib.types.str;
      default = "bovbel";
      description = "Attic client server name.";
    };

    cacheName = lib.mkOption {
      type = lib.types.str;
      default = "nixos";
      description = "Attic cache name used by watch-store clients.";
    };

    client = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable attic watch-store client.";
      };

      jobs = lib.mkOption {
        type = lib.types.ints.positive;
        default = 5;
        description = "Parallel upload jobs for attic watch-store.";
      };
    };
  };
}
