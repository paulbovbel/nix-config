{pkgs, ...}: {
  imports = [
    ../graphical
  ];

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  environment.systemPackages = [
    pkgs.distrobox
  ];

  services.flatpak.packages = [
    "com.slack.Slack"
    "us.zoom.Zoom"
  ];
}
