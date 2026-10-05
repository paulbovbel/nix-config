{lib, ...}: {
  options.mediaServer = {
    library.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run Plex, Jellyfin, Audiobookshelf, Tautulli, and the supporting media-library services.";
    };

    downloads.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run the torrent, video, and book download automation services.";
    };

    downloads.popularVideos = let
      channelType = lib.types.submodule {
        options = {
          channel = lib.mkOption {
            type = lib.types.str;
            description = "YouTube channel handle from which popular videos are selected, for example @natgeokids.";
          };

          count = lib.mkOption {
            type = lib.types.ints.positive;
            description = "Number of the channel's most popular matching videos to retain.";
          };

          maxLength = lib.mkOption {
            type = lib.types.nullOr lib.types.ints.positive;
            default = null;
            description = "Maximum retained video length in minutes, or null for no limit.";
          };
        };
      };
    in {
      channels = lib.mkOption {
        type = lib.types.listOf channelType;
        default = [];
        example = [
          {
            channel = "@example";
            count = 10;
            maxLength = 30;
          }
        ];
        description = "YouTube channels and retention limits processed by download-popular-videos.service.";
      };

      calendar = lib.mkOption {
        type = lib.types.str;
        default = "weekly";
        description = "systemd OnCalendar schedule for download-popular-videos.timer.";
      };
    };
  };
}
