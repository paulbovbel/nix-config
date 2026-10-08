{lib, ...}: {
  options.tailscale.domain = lib.mkOption {
    type = lib.types.str;
    example = "example.ts.net";
    description = "Tailscale MagicDNS domain for this tailnet.";
  };
}
