{
  config,
  lib,
  pkgs,
  graphicalSessions,
  unstablePkgs,
  caelestia-shell,
  caelestia-dots,
  ...
}: let
  headsetcontrolPackage = unstablePkgs.headsetcontrol;
  sessionDefaults = pkgs.writeText "graphical-user-sessions.json" (builtins.toJSON config.graphical.resolvedUserShells);
in {
  imports = [
    ./options.nix
    ./visual.nix
    ./shells/gnome/system.nix
    ./shells/hyprland/system.nix
  ];

  config = lib.mkIf (builtins.elem "graphical" config.systemProfiles) {
    home-manager = {
      extraSpecialArgs = {
        inherit headsetcontrolPackage;
        inherit caelestia-shell caelestia-dots;
      };
      sharedModules = [caelestia-shell.homeManagerModules.default];
      users =
        lib.mapAttrs (_: shell: {
          _module.args.graphicalShell = shell;
        })
        config.graphical.resolvedUserShells;
    };

    systemd.services.graphical-user-sessions = {
      description = "Set per-user graphical login sessions";
      wantedBy = ["multi-user.target"];
      before = ["display-manager.service"];
      after = ["accounts-daemon.service"];
      requires = ["accounts-daemon.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${lib.getExe graphicalSessions} set-defaults ${sessionDefaults}";
      };
    };

    networking.networkmanager = {
      enable = true;
      dns = "systemd-resolved";
    };

    services = {
      pulseaudio.enable = false;
      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        jack.enable = true;
        pulse.enable = true;
      };

      udev.packages = [headsetcontrolPackage];

      flatpak = {
        enable = true;
        remotes = [
          {
            name = "flathub";
            location = "https://flathub.org/repo/flathub.flatpakrepo";
          }
        ];
        packages =
          [
            "org.mozilla.firefox"
            "com.bitwarden.desktop"
            "org.gimp.GIMP"
            "org.inkscape.Inkscape"
            "com.rtosta.zapzap"
          ]
          ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
            "com.bambulab.BambuStudio"
            "com.spotify.Client"
            "com.discordapp.Discord"
            "org.signal.Signal"
            "tv.plex.PlexDesktop"
          ];
        overrides.settings."com.rtosta.zapzap".Environment = {
          QTWEBENGINE_DISABLE_GPU = "1";
          QT_QUICK_BACKEND = "software";
        };
        overrides.settings."com.bitwarden.desktop".Context.filesystems = [
          "~/.mozilla/native-messaging-hosts:create"
        ];
      };

      xserver = {
        enable = true;
        xkb = {
          layout = "us";
          variant = "";
        };
      };
      displayManager.gdm.enable = true;
      # GDM's global default resets every user's AccountsService preference.
      # The graphical-user-sessions service supplies per-user defaults instead.
      displayManager.defaultSession = lib.mkDefault null;
      gnome.gnome-keyring.enable = true;
      printing.enable = true;
    };

    security.rtkit.enable = true;

    hardware.logitech.wireless = {
      enable = true;
      enableGraphical = true;
    };

    security.pam.loginLimits = [
      {
        domain = "@users";
        type = "-";
        item = "rtprio";
        value = "95";
      }
      {
        domain = "@users";
        type = "-";
        item = "nice";
        value = "-11";
      }
      {
        domain = "@users";
        type = "-";
        item = "memlock";
        value = "unlimited";
      }
    ];

    environment = {
      systemPackages = [
        headsetcontrolPackage
        pkgs.libva-utils
        pkgs.qpwgraph
        pkgs.remmina
        pkgs.vlc
        pkgs.wireshark
        pkgs.xrandr
      ];

      sessionVariables = {
        TERMINAL = "kitty";
      };
    };

    rootFs.persistDirectories = [
      "/etc/NetworkManager/system-connections"
      "/var/lib/cups"
      "/var/lib/bluetooth"
      "/var/lib/flatpak"
      "/var/lib/gdm"
      "/var/lib/AccountsService"
      "/var/lib/NetworkManager"
    ];
  };
}
