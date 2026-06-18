{lib, ...}: {
  options.mediaServer = {
    library.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Plex, Jellyfin, and Tautulli services.";
    };

    downloads.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable download manager services.";
    };

    upnp.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether media-server services declare their UPnP forwards.";
    };
  };
}
