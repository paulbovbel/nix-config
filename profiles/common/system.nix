{
  config,
  lib,
  ...
}: {
  imports = [
    ./boot.nix
    ./mail.nix
    ./services.nix
    ./core.nix
  ];

  config = lib.mkIf (config.systemProfiles != []) {
    tailnet.enable = true;

    age.secrets.tailscale-mcp-env = lib.mkIf (config.userProfiles.pbovbel != []) {
      file = ../../secrets/common/tailscale-mcp-env.age;
      owner = "pbovbel";
      mode = "0400";
    };

    grafanaCloud = {
      enable = true;
      smartctl.enable = true;
    };

    llamaCpp.client.enable = true;
  };
}
