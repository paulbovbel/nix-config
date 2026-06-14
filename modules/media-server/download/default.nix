{
  config,
  lib,
  ...
}: let
  cfg = config.mediaServer;
in {
  imports = [
    ./torrent.nix
    ./video.nix
    ./books.nix
  ];

  config = lib.mkIf (cfg.enable && cfg.components.downloads.enable) {
    storage.datasets.downloads.autoSnapshot.enable = false;
  };
}
