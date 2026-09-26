{
  config,
  lib,
  ...
}: let
  cfg = config.gameServer;
  datasets = config.storage.datasets;
  inherit (config.podmanServer) user;
in {
  config = lib.mkIf cfg.minecraft.enable {
    age.secrets.web-credentials-env.file = ../../secrets/server/web-credentials-env.age;

    storage.datasets.app.children.minecraft = {};

    podmanServer = {
      derivedEnvFiles.minecraft = {
        secretEnvironmentFiles = [config.age.secrets.web-credentials-env.path];
        variables.RCON_PASSWORD = "$WEB_PASSWORD";
      };

      containers.minecraft = {
        quadlet.containerConfig = {
          image = "ghcr.io/itzg/minecraft-server:java21";
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
            MODRINTH_MODPACK = "https://modrinth.com/modpack/cobbleverse";
            SEED = "-8021755361276700313";
          };
        };
        derivedEnvironmentFiles = ["minecraft"];
      };
    };
  };
}
