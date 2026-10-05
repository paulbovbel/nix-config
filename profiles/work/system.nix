{
  locus-vpn-client,
  pkgs,
  ...
}: {
  imports = [
    ../graphical/system.nix
    locus-vpn-client.nixosModules.default
  ];

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  programs.locus-vpn-client = {
    enable = true;
    splitTunnelDefault = true;
    networkManagerIntegration.enable = true;
  };

  rootFs.persistDirectories = [
    "/etc/ipsec.d"
  ];

  environment = {
    systemPackages = [
      pkgs.docker-compose
      pkgs.distrobox
      pkgs.ike-scan
      pkgs.podman-compose
      pkgs.xhost
    ];
  };

  services.flatpak.packages = [
    "com.slack.Slack"
    "us.zoom.Zoom"
  ];
}
