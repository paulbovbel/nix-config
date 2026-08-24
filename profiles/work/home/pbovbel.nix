{
  lib,
  pkgs,
  ...
}: let
  cliPackages = import ../../common/cli-packages.nix {inherit pkgs;};
  pythonWithPsutil = pkgs.python3.withPackages (pythonPackages: [
    pythonPackages.psutil
  ]);
  kittyDistroboxSplit = pkgs.writeShellApplication {
    name = "kitty-distrobox-split";
    runtimeInputs = [
      pkgs.bashInteractive
      pkgs.distrobox
      pkgs.kitty
      pythonWithPsutil
    ];
    text = ''
      exec python3 ${./kitty-distrobox-split.py} "$@"
    '';
  };
  kittyDistroboxSplitBinding = location: "launch --type=background --allow-remote-control ${lib.getExe kittyDistroboxSplit} ${location}";
  mkAutostart = import ../../graphical/autostart.nix;
  mkHostWrapper = command: ''
    sudo install -Dm755 /dev/stdin /usr/local/bin/${command} <<'EOF'
    #!/usr/bin/env sh
    exec host-spawn ${command} "$@"
    EOF
  '';
in {
  imports = [
    ../../graphical/home/pbovbel.nix
  ];

  dconf.settings."org/gnome/shell".favorite-apps = lib.mkAfter [
    "us.zoom.Zoom.desktop"
    "com.slack.Slack.desktop"
  ];

  home.packages = [
    pkgs.chromium
    pkgs.github-copilot-cli
  ];

  programs.kitty.keybindings = {
    "ctrl+shift+e" = lib.mkForce (kittyDistroboxSplitBinding "vsplit");
    "ctrl+shift+o" = lib.mkForce (kittyDistroboxSplitBinding "hsplit");
  };

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

          if ! ${pkgs.distrobox}/bin/distrobox list --no-color | ${pkgs.gnugrep}/bin/grep -Fq ${lib.escapeShellArg name}; then
            ${pkgs.distrobox}/bin/distrobox create \
              --yes \
              --name ${lib.escapeShellArg name} \
              --image ${lib.escapeShellArg image} \
              --additional-packages ${lib.escapeShellArgs cliPackages.aptPackages} \
              --init-hooks ${lib.escapeShellArg (lib.concatMapStrings mkHostWrapper ["xrandr" "nmcli"])}
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

  xdg.configFile = lib.mkMerge (map mkAutostart [
    {
      file = "slack";
      name = "Slack";
      exec = "flatpak run com.slack.Slack";
    }
    {
      file = "zoom";
      name = "Zoom";
      exec = "flatpak run us.zoom.Zoom";
    }
  ]);
}
