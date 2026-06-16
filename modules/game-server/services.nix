{
  config,
  lib,
  ...
}: let
  cfg = config.gameServer;
  podmanCfg = config.podmanServer;
  datasets = config.storage.datasets;
  inherit (podmanCfg) user;
  containerUser = "${toString user.uid}:${toString user.gid}";
in {
  config = lib.mkIf cfg.enable {
    age.secrets = lib.mkMerge [
      (lib.mkIf cfg.components.minecraft.enable {
        web-credentials-env.file = ../../secrets/server/web-credentials-env.age;
      })
      (lib.mkIf cfg.components.abiotic.enable {
        abiotic-env.file = ../../secrets/server/abiotic-env.age;
      })
    ];

    storage.datasets.app.children = {
      abiotic = lib.mkIf cfg.components.abiotic.enable {};
      minecraft = lib.mkIf cfg.components.minecraft.enable {};
    };

    podmanServer = {
      derivedEnvFiles.minecraft = lib.mkIf cfg.components.minecraft.enable {
        secretEnvironmentFiles = [config.age.secrets.web-credentials-env.path];
        variables.RCON_PASSWORD = "$WEB_PASSWORD";
      };

      containers = {
        minecraft = lib.mkIf cfg.components.minecraft.enable {
          quadlet.containerConfig = {
            image = "itzg/minecraft-server";
            publishPorts = ["25565:25565"];
            volumes = ["${datasets.app.children.minecraft.path}:/data"];
            environments = {
              UID = toString user.uid;
              GID = toString user.gid;
              EULA = "TRUE";
              MAX_MEMORY = "16G";
              ENABLE_AUTOPAUSE = "TRUE";
              WHITELIST = lib.concatStringsSep "," cfg.minecraft.users;
              OPS = lib.concatStringsSep "," cfg.minecraft.ops;
              ENABLE_RCON = "TRUE";
              VERSION = "1.21.1";
              MODPACK_PLATFORM = "MODRINTH";
              MODRINTH_MODPACK = "default3.mrpack";
              SEED = "-7903651094132931013";
            };
          };
          derivedEnvironmentFiles = ["minecraft"];
        };

        abiotic = lib.mkIf cfg.components.abiotic.enable {
          quadlet.containerConfig = {
            image = "ghcr.io/pleut/abiotic-factor-linux-docker:latest";
            user = containerUser;
            publishPorts = ["7777:7777/udp" "27015:27015/udp"];
            volumes = [
              "${datasets.app.children.abiotic.path}/gamefiles:/server"
              "${datasets.app.children.abiotic.path}/data:/server/AbioticFactor/Saved"
            ];
            environments = {
              MaxServerPlayers = "6";
              Port = "7777";
              QueryPort = "27015";
              SteamServerName = "bovbel";
              UsePerfThreads = "true";
              NoAsyncLoadingThread = "true";
              WorldSaveName = "Cascade";
              AutoUpdate = "true";
            };
          };
          secretEnvironmentFiles = [config.age.secrets.abiotic-env.path];
        };
      };
    };

    upnp.forwards = lib.mkIf (cfg.upnp.enable && cfg.components.abiotic.enable) {
      abiotic = {
        from = 7777;
        to = 7777;
        proto = "udp";
      };
      abioticquery = {
        from = 27015;
        to = 27015;
        proto = "udp";
      };
    };
  };
}
