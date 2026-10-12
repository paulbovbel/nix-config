{lib, ...}: {
  options.tailnet = {
    enable = lib.mkEnableOption "automatic Tailscale enrollment and persistent device state";
    domain = lib.mkOption {
      type = lib.types.str;
      example = "example.ts.net";
      description = "Tailscale MagicDNS domain for this tailnet.";
    };
    tags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Machine identity tags advertised during automatic Tailscale enrollment. Configure OAuth tag ownership before changing these tags.";
    };
  };
}
