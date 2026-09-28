{lib, ...}: {
  options.gameServer = {
    abiotic.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run the containerized Abiotic Factor dedicated server.";
    };

    minecraft = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Run the containerized Minecraft dedicated server.";
      };

      ops = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Minecraft usernames written to ops.json with operator privileges.";
      };
      users = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Minecraft usernames written to whitelist.json and allowed to join.";
      };
    };

    valheim = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Run the containerized Valheim dedicated server.";
      };

      admins = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Valheim administrator display names mapped to SteamID64 values.";
      };

      permittedUsers = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Valheim permitted-player display names mapped to SteamID64 values.";
      };

      modifiers = {
        combat = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum ["veryeasy" "easy" "hard" "veryhard"]);
          default = null;
          description = "Valheim combat difficulty, or null to use the game default.";
        };

        deathPenalty = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum ["casual" "veryeasy" "easy" "hard" "hardcore"]);
          default = null;
          description = "Valheim death penalty, or null to use the game default.";
        };

        resources = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum ["muchless" "less" "more" "muchmore" "most"]);
          default = null;
          description = "Valheim resource yield, or null to use the game default.";
        };

        raids = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum ["none" "muchless" "less" "more" "muchmore"]);
          default = null;
          description = "Valheim raid frequency, or null to use the game default.";
        };

        portals = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum ["casual" "hard" "veryhard"]);
          default = null;
          description = "Valheim portal restrictions, or null to use the game default.";
        };

        playerBasedRaids = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Use Valheim's player-based raid scaling.";
        };
      };

      serverName = lib.mkOption {
        type = lib.types.str;
        default = "bovbel";
        description = "Dedicated-server name shown in the Valheim server browser.";
      };

      worldName = lib.mkOption {
        type = lib.types.str;
        default = "Dedicated";
        description = "Valheim world name loaded from persistent server storage.";
      };
    };

    upnp.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether enabled game servers request their public port forwards through the UPnP module.";
    };
  };
}
