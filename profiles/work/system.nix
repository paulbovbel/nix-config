{
  config,
  lib,
  locus-vpn-client,
  pkgs,
  ...
}: {
  imports = [
    locus-vpn-client.nixosModules.default
  ];

  config = lib.mkIf (builtins.elem "work" config.systemProfiles) {
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
  };
}
