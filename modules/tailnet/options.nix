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
    policy = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Native Tailscale policy declared in the shared site configuration; passed through unchanged apart from appended container grants.";
    };
    containerGrants = lib.mkOption {
      default = [];
      description = "Grants populated with declared tailnet container ports. Referenced hosts and containers must exist; omit disabled containers explicitly.";
      type = lib.types.listOf (lib.types.submodule {
        options = {
          host = lib.mkOption {
            type = lib.types.str;
            description = "Fleet host containing the services.";
          };
          containers = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Names of enabled containers whose tailnet ports are granted.";
          };
          grant = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            description = "Native Tailscale grant without ip; the generator supplies its ports.";
          };
        };
      });
    };
  };
}
