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
      ports = map (port: {
        hostPort = port;
        protocol = "udp";
        exposure = ["wan" "tailnet"];
      }) [7777 27015];
      quadlet.containerConfig = {
        image = "ghcr.io/pleut/abiotic-factor-linux-docker:latest";
        user = containerUser;
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
  };
}
