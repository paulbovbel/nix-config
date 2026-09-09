{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.gameServer;
  datasets = config.storage.datasets;
  inherit (config.podmanServer) user;
  steamPlatformIds = users: map (steamId: "V_${steamId}") (lib.attrValues users);
  modifierArgs = lib.concatStringsSep " " (
    (lib.mapAttrsToList (
        name: value: "-modifier ${name} ${value}"
      )
      (lib.filterAttrs (_: value: value != null) {
        inherit (cfg.valheim.modifiers) combat portals raids resources;
        deathpenalty = cfg.valheim.modifiers.deathPenalty;
      }))
    ++ lib.optional cfg.valheim.modifiers.playerBasedRaids "-setkey playerevents"
  );
in {
  config = lib.mkIf cfg.valheim.enable {
    age.secrets.game-server-env.file = ../../secrets/server/game-server-env.age;

    storage.datasets.app.children.valheim = {};

    podmanServer.derivedEnvFiles.valheim = {
      secretEnvironmentFiles = [config.age.secrets.game-server-env.path];
      variables.SERVER_PASS = "$SERVER_PASSWORD";
    };

    podmanServer.containers.valheim = {
      quadlet.serviceConfig = {
        ExecStartPre = [
          "${pkgs.coreutils}/bin/install -d -m 0755 -o ${user.name} -g ${user.group} ${datasets.app.children.valheim.path}/config ${datasets.app.children.valheim.path}/data"
        ];
        TimeoutStopSec = 120;
      };
      quadlet.containerConfig = {
        image = "ghcr.io/community-valheim-tools/valheim-server:latest";
        addCapabilities = ["SYS_NICE"];
        publishPorts = ["2456:2456/udp" "2457:2457/udp"];
        volumes = [
          "${datasets.app.children.valheim.path}/config:/config"
          "${datasets.app.children.valheim.path}/data:/opt/valheim"
        ];
        environments = {
          PUID = toString user.uid;
          PGID = toString user.gid;
          ADMINLIST_IDS = lib.concatStringsSep " " (steamPlatformIds cfg.valheim.admins);
          PERMITTEDLIST_IDS = lib.concatStringsSep " " (
            lib.unique (steamPlatformIds (cfg.valheim.admins // cfg.valheim.permittedUsers))
          );
          SERVER_NAME = cfg.valheim.serverName;
          WORLD_NAME = cfg.valheim.worldName;
          SERVER_PUBLIC = "true";
          SERVER_ARGS = modifierArgs;
        };
      };
      derivedEnvironmentFiles = ["valheim"];
    };

    upnp.forwards = lib.mkIf cfg.upnp.enable {
      valheim = {
        from = 2456;
        to = 2456;
        proto = "udp";
      };
      valheimQuery = {
        from = 2457;
        to = 2457;
        proto = "udp";
      };
    };
  };
}
