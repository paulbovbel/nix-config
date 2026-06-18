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

    records = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };
  };
}
