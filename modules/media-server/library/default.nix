{
  config,
  lib,
  ...
}: let
  cfg = config.mediaServer;
in {
  imports = [
    ./jellyfin.nix
    ./plex.nix
    ./books.nix
  ];

  config = lib.mkIf cfg.library.enable {
    storage.datasets.media = {
      autoSnapshot = {
        enable = true;
        frequent = false;
        hourly = false;
        daily = true;
        weekly = true;
        monthly = false;
      };

      children = {
        audiobooks.options.recordsize = "1M";
        books = {};
        comics = {};
        movies.options.recordsize = "1M";
        tv.options.recordsize = "1M";
      };
    };
  };
}
