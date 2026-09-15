{lib, ...}: {
  options.ddns = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable public dynamic DNS updates and tailnet DNS responses.";
    };

    zone = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "DNS zone containing the dynamically updated records.";
    };

    records = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "DNS record names mapped to the host's public and Tailscale addresses.";
    };
  };
}
