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
