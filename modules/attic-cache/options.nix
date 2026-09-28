{lib, ...}: {
  options.atticCache = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run the Attic binary cache server and expose it through Caddy.";
    };

    subdomain = lib.mkOption {
      type = lib.types.str;
      default = "nix-cache";
      description = "Subdomain of networking.domain used for the public Attic endpoint.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port on which atticd accepts requests from Caddy.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/attic";
      description = "Directory containing Attic server metadata and its SQLite database.";
    };

    serverName = lib.mkOption {
      type = lib.types.str;
      default = "bovbel";
      description = "Server alias used by Attic clients, for example in bovbel:nixos.";
    };

    cacheName = lib.mkOption {
      type = lib.types.str;
      default = "nixos";
      description = "Cache name to which watch-store clients upload Nix store paths.";
    };

    client = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Continuously upload newly created local Nix store paths to this Attic cache.";
      };

      jobs = lib.mkOption {
        type = lib.types.ints.positive;
        default = 5;
        description = "Maximum parallel uploads performed by the Attic watch-store client.";
      };
    };
  };
}
