{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.atticCache;
  domain = "${cfg.subdomain}.${config.caddy.publicDomain}";
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
      age.secrets.attic-server-env.file = ../../secrets/server/attic-server-env.age;

      services.atticd = {
        enable = true;
        user = "atticd";
        group = "atticd";
        environmentFile = config.age.secrets.attic-server-env.path;
        settings = {
          listen = "0.0.0.0:${toString cfg.port}";
          allowed-hosts = [domain];
          api-endpoint = endpoint;
          database.url = "sqlite:${cfg.dataDir}/server.db?mode=rwc";
          storage = {
            type = "local";
            path = "${cfg.dataDir}/storage";
          };
        };
      };

      systemd.services.atticd = {
        after = ["systemd-tmpfiles-setup.service"];
        unitConfig.RequiresMountsFor = [cfg.dataDir];
        serviceConfig = {
          DynamicUser = lib.mkForce false;
          PrivateUsers = lib.mkForce false;
          ReadWritePaths = [cfg.dataDir];
        };
      };

      users.users.atticd = {
        isSystemUser = true;
        group = "atticd";
      };

      users.groups.atticd = {};

      caddy.domains.${domain} = {
        auth = null;
        host = "host.containers.internal";
        inherit (cfg) port;
      };

      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0750 atticd atticd -"
        "d ${cfg.dataDir}/storage 0750 atticd atticd -"
        "z ${cfg.dataDir} 0750 atticd atticd -"
        "z ${cfg.dataDir}/storage 0750 atticd atticd -"
      ];

      impermanenceRoot.datasets."root/attic" = {
        type = "zfs_fs";
        mountpoint = cfg.dataDir;
        options = {
          "com.sun:auto-snapshot" = "false";
          quota = "100G";
        };
      };

      networking.firewall.interfaces.podman1.allowedTCPPorts = [cfg.port];
    })

    (lib.mkIf cfg.client.enable {
      age.secrets.attic-watch-store-token.file = ../../secrets/common/attic-watch-store-token.age;

      environment.systemPackages = [pkgs.attic-client];

      systemd.services.attic-watch-store = {
        description = "Upload new Nix store paths to Attic";
        wantedBy = ["multi-user.target"];
        wants = ["network-online.target"];
        after = ["network-online.target" "nix-daemon.service"];
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
