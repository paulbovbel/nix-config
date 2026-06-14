{lib, ...}: let
  componentOption = description:
    lib.mkOption {
      type = lib.types.bool;
      default = true;
      inherit description;
    };
in {
  options.mediaServer = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable media server services.";
    };

    components = {
      library.enable = componentOption "Enable Plex, Jellyfin, and Tautulli components.";
      downloads.enable = componentOption "Enable download manager components.";
    };

    upnp.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether media-server services declare their UPnP forwards.";
    };
  };
}
