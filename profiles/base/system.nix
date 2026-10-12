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

    grafanaCloud = {
      enable = true;
      smartctl.enable = true;
    };

    llamaCpp.client.enable = true;
  };
}
