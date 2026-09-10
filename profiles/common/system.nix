{
  imports = [
    ./boot.nix
    ./mail.nix
    ./services.nix
    ./core.nix
  ];

  grafanaCloud = {
    enable = true;
    smartctl.enable = true;
  };
}
