{
  config,
  pkgs,
  unstablePkgs,
  ...
}: {
  imports = [
    ../common
  ];

  age.secrets.tailscale-oauth-authkey = {
    file = ../../secrets/laptop/tailscale-oauth-authkey.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  services = {
    tailscale = {
      enable = true;
      authKeyFile = config.age.secrets.tailscale-oauth-authkey.path;
      extraUpFlags = ["--advertise-tags=tag:laptop"];
    };

    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      jack.enable = true;
      pulse.enable = true;

      # Conservative low-latency defaults for gaming/voice.
      extraConfig.pipewire."10-low-latency" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.quantum" = 128;
          "default.clock.min-quantum" = 64;
          "default.clock.max-quantum" = 256;
        };
      };
    };

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
    etc."xdg/kitty/kitty.conf".text = ''
      map ctrl+shift+e launch --location=vsplit --cwd=current
      map ctrl+shift+o launch --location=hsplit --cwd=current

      map alt+left neighboring_window left
      map alt+right neighboring_window right
      map alt+up neighboring_window up
      map alt+down neighboring_window down

      enabled_layouts splits

      map ctrl+left resize_window narrower
      map ctrl+right resize_window wider
      map ctrl+up resize_window taller
      map ctrl+down resize_window shorter
      map ctrl+home resize_window reset

      scrollback_lines -1
      wheel_scroll_multiplier 5
      touch_scroll_multiplier 5

      confirm_os_window_close 0
    '';

    systemPackages = [
      pkgs.gnome-tweaks
      pkgs.gnomeExtensions.dash-to-dock
      pkgs.gnomeExtensions.appindicator
      pkgs.yaru-theme
      pkgs.kitty
      (pkgs.vscode-with-extensions.override {
        inherit (pkgs) vscode;
        vscodeExtensions = with unstablePkgs.vscode-marketplace; [
          github.codespaces
          github.copilot-chat
          github.vscode-github-actions
          github.vscode-pull-request-github
          jnoortheen.nix-ide
          kevinrose.vsc-python-indent
          ms-azuretools.vscode-containers
          ms-python.black-formatter
          ms-python.debugpy
          ms-python.python
          ms-python.vscode-pylance
          ms-python.vscode-python-envs
          ms-vscode-remote.remote-containers
          ms-vscode.cmake-tools
          ms-vscode.cpp-devtools
          ms-vscode.cpptools
          ms-vscode.cpptools-extension-pack
          ms-vscode.cpptools-themes
          redhat.vscode-yaml
          samuelcolvin.jinjahtml
          tomoki1207.pdf
          twxs.cmake
        ];
      })
    ];

    sessionVariables = {
      TERMINAL = "kitty";
      OPENAI_BASE_URL = "http://white-tower:11434/v1";
      OPENAI_API_KEY = "dummy";
    };
  };

  impermanenceRoot.persistDirectories = [
    "/var/lib/bluetooth"
    "/var/lib/flatpak"
    "/var/lib/NetworkManager"
    # "/var/lib/tailscale"
  ];
}
