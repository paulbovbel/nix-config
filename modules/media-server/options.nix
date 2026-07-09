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

    downloads.popularVideos = let
      channelType = lib.types.submodule {
        options = {
          channel = lib.mkOption {
            type = lib.types.str;
            description = "YouTube channel handle, for example @natgeokids.";
          };

          count = lib.mkOption {
            type = lib.types.ints.positive;
            description = "Number of popular videos to keep from this channel.";
          };

          maxLength = lib.mkOption {
            type = lib.types.nullOr lib.types.ints.positive;
            default = null;
            description = "Maximum video length in minutes. Null allows any length.";
          };
        };
      };
    in {
      channels = lib.mkOption {
        type = lib.types.listOf channelType;
        default = [];
        description = "YouTube channels whose most popular videos should be downloaded.";
      };

      calendar = lib.mkOption {
        type = lib.types.str;
        default = "weekly";
        description = "systemd OnCalendar schedule for downloading popular YouTube videos.";
      };
    };

    upnp.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether media-server services declare their UPnP forwards.";
    };
  };
}
