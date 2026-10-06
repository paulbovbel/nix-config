{
  config,
  lib,
  ...
}: let
  cfg = config.mediaServer;
in {
  imports = [
    ./options.nix
    ./library
    ./download
  ];

  config = lib.mkMerge [
    {
      moduleDocumentation.media-server = {
        title = "Media Server";
        category = "Applications";
        summary = "Media libraries, download automation, and related container services.";
      };
    }
    (lib.mkIf (cfg.library.enable || cfg.downloads.enable) {
      boot.kernel.sysctl."fs.inotify.max_user_watches" = 1048576;
    })
  ];
}
