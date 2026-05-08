{ ... }:

{
  imports = [
    ../graphical
  ];

  services.flatpak.packages = [
    "com.slack.Slack"
    "us.zoom.Zoom"
  ];
}
