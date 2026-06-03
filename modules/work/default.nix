{pkgs, ...}: {
  imports = [
    ../graphical
  ];

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  services.strongswan = {
    enable = true;
    secrets = ["ipsec.d/ipsec.nm-l2tp.secrets"];
  };

  networking.networkmanager.plugins = [
    pkgs.networkmanager-l2tp
  ];

  environment.systemPackages = [
    pkgs.distrobox
    pkgs.ike-scan
  ];

  services.flatpak.packages = [
    "com.slack.Slack"
    "us.zoom.Zoom"
  ];
}
