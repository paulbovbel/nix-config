{lib, ...}: {
  options.moduleDocumentation.site = lib.mkOption {
    internal = true;
    readOnly = true;
    default = {
      title = "Site";
      summary = "Settings shared by services within the local network and tailnet.";
    };
  };

  options.tailscale.domain = lib.mkOption {
    type = lib.types.str;
    example = "example.ts.net";
    description = "Tailscale MagicDNS domain for this tailnet.";
  };
}
