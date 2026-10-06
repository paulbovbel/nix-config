{lib, ...}: {
  config.moduleDocumentation.site = {
    title = "Site";
    category = "System";
    summary = "Settings shared by services within the local network and tailnet.";
  };

  options.tailscale.domain = lib.mkOption {
    type = lib.types.str;
    example = "example.ts.net";
    description = "Tailscale MagicDNS domain for this tailnet.";
  };
}
