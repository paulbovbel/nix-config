{
  lib,
  osConfig,
  pkgs,
  ...
}: let
  workEnv = osConfig.age.secrets.work-env.path;
  sourceWorkEnv = ''
    if [ -r ${workEnv} ]; then
      set -a
      . ${workEnv}
      set +a
    fi
  '';
in {
  imports = [
    ./graphical.nix
  ];

  dconf.settings."org/gnome/shell".favorite-apps = lib.mkAfter [
    "us.zoom.Zoom.desktop"
    "com.slack.Slack.desktop"
  ];

  programs.bash = {
    initExtra = sourceWorkEnv;
    profileExtra = sourceWorkEnv;
  };

  systemd.user.services = let
    mkDistroboxImage = name: tag: baseImage: rec {
      image = "localhost/distrobox-${name}:${tag}";
      inherit baseImage;
    };

    jammyImage = mkDistroboxImage "ubuntu-jammy" "22.04" "docker.io/library/ubuntu:22.04";
    nobleImage = mkDistroboxImage "ubuntu-noble" "24.04" "docker.io/library/ubuntu:24.04";
    resoluteImage = mkDistroboxImage "ubuntu-resolute" "26.04" "docker.io/library/ubuntu:26.04";

    mkDistrobox = name: image: baseImage: {
      Unit = {
        Description = "Create ${name} Distrobox";
        After = ["podman.socket"];
      };
      Service = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "create-${name}" ''
          set -euo pipefail
          ${lib.optionalString (baseImage != null) ''
            ${pkgs.podman}/bin/podman build --build-arg baseImage=${baseImage} --tag ${image} --file ${./distrobox.Containerfile} /tmp
          ''}
          if ! ${pkgs.distrobox}/bin/distrobox list --no-color | ${pkgs.gnugrep}/bin/grep -qE '(^|[|[:space:]])${name}([|[:space:]]|$)'; then
            ${pkgs.distrobox}/bin/distrobox create --yes --name ${name} --image ${image}
          fi
        '';
      };
      Install.WantedBy = ["default.target"];
    };
  in {
    distrobox-ubuntu-jammy = mkDistrobox "ubuntu-jammy" jammyImage.image jammyImage.baseImage;
    distrobox-ubuntu-noble = mkDistrobox "ubuntu-noble" nobleImage.image nobleImage.baseImage;
    distrobox-ubuntu-resolute = mkDistrobox "ubuntu-resolute" resoluteImage.image resoluteImage.baseImage;
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
