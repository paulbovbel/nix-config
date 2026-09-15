{
  config,
  lib,
  ...
}: let
  cfg = config.mediaServer;
in {
  options.moduleDocumentation.media-server = lib.mkOption {
    internal = true;
    readOnly = true;
    default = {
      title = "Media Server";
      summary = "Media libraries, download automation, and related container services.";
    };
  };

  imports = [
    ./options.nix
    ./library
    ./download
  ];

  config = lib.mkIf (cfg.library.enable || cfg.downloads.enable) {
    boot.kernel.sysctl."fs.inotify.max_user_watches" = 1048576;
  };
}
