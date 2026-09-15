{lib, ...}: {
  options.gameServer = {
    abiotic.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Abiotic Factor server.";
    };

    minecraft = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Minecraft server.";
      };

      ops = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Minecraft usernames granted operator privileges.";
      };
      users = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Minecraft usernames allowed to join the server.";
      };
    };

    valheim = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Valheim server.";
      };

      admins = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Valheim administrator usernames mapped to SteamID64 values.";
      };

      permittedUsers = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Permitted Valheim usernames mapped to SteamID64 values.";
      };

      modifiers = {
        combat = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum ["veryeasy" "easy" "hard" "veryhard"]);
          default = null;
          description = "Valheim combat difficulty modifier.";
        };

        deathPenalty = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum ["casual" "veryeasy" "easy" "hard" "hardcore"]);
          default = null;
          description = "Valheim death penalty modifier.";
        };

        resources = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum ["muchless" "less" "more" "muchmore" "most"]);
          default = null;
          description = "Valheim resource rate modifier.";
        };

        raids = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum ["none" "muchless" "less" "more" "muchmore"]);
          default = null;
          description = "Valheim raid frequency modifier.";
        };

        portals = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum ["casual" "hard" "veryhard"]);
          default = null;
          description = "Valheim portal restriction modifier.";
        };

        playerBasedRaids = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Scale Valheim raids based on the participating players.";
        };
      };

      serverName = lib.mkOption {
        type = lib.types.str;
        default = "bovbel";
        description = "Name shown in the Valheim server browser.";
      };

      worldName = lib.mkOption {
        type = lib.types.str;
        default = "Dedicated";
        description = "Name of the Valheim world to load.";
      };
    };

    upnp.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether game-server services declare their UPnP forwards.";
    };
  };
}
