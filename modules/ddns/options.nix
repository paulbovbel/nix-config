{lib, ...}: {
  options.ddns = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable dynamic DNS record updates.";
    };

    zone = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "DNS zone containing the dynamically updated records.";
    };

    records = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "DNS record names to update with the host's public address.";
    };
  };
}
