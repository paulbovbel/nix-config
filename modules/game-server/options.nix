{lib, ...}: let
  componentOption = description:
    lib.mkOption {
      type = lib.types.bool;
      default = true;
      inherit description;
    };
in {
  options.gameServer = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable game server services.";
    };

    components = {
      minecraft.enable = componentOption "Enable Minecraft server.";
      abiotic.enable = componentOption "Enable Abiotic Factor server.";
    };

    minecraft = {
      ops = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
      users = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
    };

    upnp.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether game-server services declare their UPnP forwards.";
    };
  };
}
