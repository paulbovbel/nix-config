{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.atticCache;
  cacheDir = "/var/lib/attic/storage";
  datasets = config.storage.datasets;
  domain = "${cfg.subdomain}.${config.networking.domain}";
  endpoint = "https://${domain}/";
  watchStore = pkgs.writeShellApplication {
    name = "attic-watch-store";
    runtimeInputs = [pkgs.attic-client pkgs.coreutils];
    text = builtins.readFile ./attic-watch-store.sh;
  };
in {
  imports = [./options.nix];

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.storage.enable;
          message = "atticCache.enable requires storage.enable for atticd data storage.";
        }
      ];

      age.secrets = {
        attic-server-env.file = ../../secrets/server/attic-server-env.age;
      };

      atticCache.dataDir = lib.mkDefault datasets.app.children.attic.path;

      storage.datasets.app.children.attic = {
        owner = "atticd";
        group = "atticd";
        mode = "0750";
      };

      rootZfs.datasets."root/attic" = {
        type = "zfs_fs";
        mountpoint = cacheDir;
        options = {
          "com.sun:auto-snapshot" = "false";
          quota = "100G";
        };
      };

      services.atticd = {
        enable = true;
        user = "atticd";
        group = "atticd";
        environmentFile = config.age.secrets.attic-server-env.path;
        settings = {
          listen = "0.0.0.0:${toString cfg.port}";
          allowed-hosts = [domain];
          api-endpoint = endpoint;
          database.url = "sqlite://${cfg.dataDir}/server.db?mode=rwc";
          storage = {
            type = "local";
            path = cacheDir;
          };
        };
      };

      systemd.services.atticd = {
        description = "Serve the Attic binary cache from shared storage";
        after = ["systemd-tmpfiles-setup.service"];
        unitConfig.RequiresMountsFor = [config.storage.dataPath cfg.dataDir cacheDir];
        serviceConfig = {
          # Attic uses ZFS-backed paths outside systemd's StateDirectory lifecycle,
          # so it needs the stable atticd user instead of transient UID mapping.
          DynamicUser = lib.mkForce false;
          ExecStartPre = [
            "+${pkgs.coreutils}/bin/install -d -o atticd -g atticd -m 0750 ${cfg.dataDir}"
            "+${pkgs.coreutils}/bin/install -d -o atticd -g atticd -m 0750 ${cacheDir}"
          ];
          PrivateUsers = lib.mkForce false;
          ReadWritePaths = [cfg.dataDir cacheDir];
        };
      };

      users.users.atticd = {
        isSystemUser = true;
        group = "atticd";
      };

      users.groups.atticd = {};

      caddy.sites.nix-cache = {
        domains = [
          {
            host = domain;
          }
        ];
        endpoints.attic = {
          type = "proxy";
          auth = null;
          path = "/";
          host = "host.containers.internal";
          inherit (cfg) port;
        };
        notFound = false;
      };

      networking.firewall.interfaces.${config.podmanServer.networkInterface}.allowedTCPPorts = [cfg.port];
    })

    (lib.mkIf cfg.client.enable {
      age.secrets.attic-watch-store-token.file = ../../secrets/common/attic-watch-store-token.age;

      environment.systemPackages = [pkgs.attic-client];

      systemd.services.attic-watch-store = {
        description = "Continuously upload new local Nix store paths to Attic";
        wantedBy = ["multi-user.target"];
        wants = ["agenix-install-secrets.service" "network-online.target"];
        after = ["agenix-install-secrets.service" "network-online.target" "nix-daemon.service"];
        unitConfig.ConditionPathExists = config.age.secrets.attic-watch-store-token.path;
        environment = {
          ATTIC_CACHE = "${cfg.serverName}:${cfg.cacheName}";
          ATTIC_ENDPOINT = endpoint;
          ATTIC_JOBS = toString cfg.client.jobs;
          ATTIC_SERVER_NAME = cfg.serverName;
          ATTIC_TOKEN_FILE = config.age.secrets.attic-watch-store-token.path;
          HOME = "/var/lib/attic-watch-store";
        };
        serviceConfig = {
          Type = "simple";
          ExecStart = "${watchStore}/bin/attic-watch-store";
          StateDirectory = "attic-watch-store";
          Restart = "always";
          RestartSec = 30;
        };
      };
    })
  ];
}
