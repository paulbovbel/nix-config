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
    grafanaCloud = {
      enable = true;
      smartctl.enable = true;
    };

    llamaCpp.client.enable = true;
  };
}
