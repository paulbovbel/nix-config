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
  config = lib.mkIf cfg.abiotic.enable {
    age.secrets.game-server-env.file = ../../secrets/server/game-server-env.age;

    storage.datasets.app.children.abiotic = {};

    podmanServer.derivedEnvFiles.abiotic = {
      secretEnvironmentFiles = [config.age.secrets.game-server-env.path];
      variables.ServerPassword = "$SERVER_PASSWORD";
    };

    podmanServer.containers.abiotic = {
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
      derivedEnvironmentFiles = ["abiotic"];
    };

    upnp.forwards = lib.mkIf cfg.upnp.enable {
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
