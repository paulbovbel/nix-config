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

  config = lib.mkIf (cfg.library.enable || cfg.downloads.enable) {
    boot.kernel.sysctl."fs.inotify.max_user_watches" = 1048576;
  };
}
