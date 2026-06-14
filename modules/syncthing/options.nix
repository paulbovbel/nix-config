{lib, ...}: {
  options.syncthing = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable native Syncthing service.";
    };

    caddy.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Syncthing through Caddy.";
    };
  };
}
