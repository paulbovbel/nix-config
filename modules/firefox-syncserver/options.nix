{lib, ...}: {
  options.firefoxSyncServer = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Firefox Sync server.";
    };

    subdomain = lib.mkOption {
      type = lib.types.str;
      default = "firefox-sync";
      description = "Public subdomain used for the Firefox Sync endpoint.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5000;
      description = "Local Firefox Sync server listen port.";
    };

    capacity = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 10;
      description = "Maximum Firefox Sync accounts allowed on this single-node server.";
    };
  };
}
