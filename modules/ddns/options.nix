{lib, ...}: {
  options.ddns = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    zone = lib.mkOption {
      type = lib.types.str;
      default = "";
    };

    record = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
  };
}
