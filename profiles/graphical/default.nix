{
  config,
  pkgs,
  ...
}: let
  firefoxSyncTokenserverUri = "https://firefox-sync.bovbel.com/1.0/sync/1.5";
in {
  imports = [
    ../common
  ];

  catppuccin = {
    enable = true;
    flavor = "mocha";
    accent = "mauve";
  };

  boot = {
    kernelParams = [
      "quiet"
      "splash"
    ];
    plymouth.enable = true;
  };

  age.secrets.tailscale-oauth-authkey = {
    file = ../../secrets/laptop/tailscale-oauth-authkey.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  networking.networkmanager = {
    enable = true;
    dns = "systemd-resolved";
  };

  services = {
    tailscale = {
      enable = true;
      authKeyFile = config.age.secrets.tailscale-oauth-authkey.path;
      authKeyParameters.ephemeral = false;
      extraUpFlags = [
        "--advertise-tags=tag:graphical"
        "--hostname=${config.networking.hostName}"
      ];
    };

    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      jack.enable = true;
      pulse.enable = true;
    };

    udev.packages = [pkgs.headsetcontrol];

    flatpak = {
      enable = true;
      remotes = [
        {
          name = "flathub";
          location = "https://flathub.org/repo/flathub.flatpakrepo";
        }
      ];
      packages = [
        "org.mozilla.firefox"
        "com.spotify.Client"
        "com.discordapp.Discord"
        "org.gimp.GIMP"
        "org.inkscape.Inkscape"
        "org.signal.Signal"
        "com.rtosta.zapzap"
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
    desktopManager.gnome.enable = true;
    displayManager.defaultSession = "gnome";
    gnome.gnome-remote-desktop.enable = true;
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
    etc."firefox/policies/policies.json".text = builtins.toJSON {
      policies.Preferences."identity.sync.tokenserver.uri" = {
        Value = firefoxSyncTokenserverUri;
        Status = "locked";
      };
    };

    systemPackages = [
      pkgs.gnome-tweaks
      pkgs.gnomeExtensions.dash-to-dock
      pkgs.gnomeExtensions.appindicator
      pkgs.gnomeExtensions.headsetcontrol
      pkgs.gnome-icon-theme
      pkgs.headsetcontrol
      pkgs.yaru-theme
      pkgs.libva-utils
      pkgs.nvtopPackages.nvidia
      pkgs.qpwgraph
      pkgs.remmina
      pkgs.vlc
      pkgs.wireshark
      pkgs.xrandr
    ];

    sessionVariables = {
      TERMINAL = "kitty";
      OPENAI_BASE_URL = "http://white-tower:11434/v1";
      OPENAI_API_KEY = "dummy";
    };
  };

  rootZfs.persistDirectories = [
    "/etc/NetworkManager/system-connections"
    "/var/lib/cups"
    "/var/lib/bluetooth"
    "/var/lib/flatpak"
    "/var/lib/gdm"
    "/var/lib/NetworkManager"
    "/var/lib/tailscale"
  ];
}
