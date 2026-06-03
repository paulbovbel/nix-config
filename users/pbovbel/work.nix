{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./graphical.nix
  ];

  dconf.settings."org/gnome/shell".favorite-apps = lib.mkAfter [
    "us.zoom.Zoom.desktop"
    "com.slack.Slack.desktop"
  ];

  systemd.user.services = let
    mkDistrobox = name: image: {
      Unit = {
        Description = "Create ${name} Distrobox";
        After = ["podman.socket"];
      };
      Service = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "create-${name}" ''
          set -euo pipefail
          if ! ${pkgs.distrobox}/bin/distrobox list --no-color | ${pkgs.gnugrep}/bin/grep -qE '(^|[|[:space:]])${name}([|[:space:]]|$)'; then
            ${pkgs.distrobox}/bin/distrobox create --yes --name ${name} --image ${image}
          fi
        '';
      };
      Install.WantedBy = ["default.target"];
    };
  in {
    distrobox-ubuntu-jammy = mkDistrobox "ubuntu-jammy" "docker.io/library/ubuntu:22.04";
    distrobox-ubuntu-noble = mkDistrobox "ubuntu-noble" "docker.io/library/ubuntu:24.04";
    distrobox-ubuntu-resolute = mkDistrobox "ubuntu-resolute" "docker.io/library/ubuntu:26.04";
  };

  xdg.configFile = {
    "autostart/slack.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Version=1.0
      Name=Slack
      Exec=flatpak run com.slack.Slack
      X-GNOME-Autostart-enabled=true
    '';

    "autostart/zoom.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Version=1.0
      Name=Zoom
      Exec=flatpak run us.zoom.Zoom
      X-GNOME-Autostart-enabled=true
    '';

    "autostart/whatsapp.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Version=1.0
      Name=ZapZap
      Exec=flatpak run com.rtosta.zapzap
      X-GNOME-Autostart-enabled=true
    '';
  };
}
