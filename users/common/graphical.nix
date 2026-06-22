{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./base.nix
  ];

  dconf.enable = true;

  catppuccin = {
    enable = true;
    autoEnable = true;
    flavor = "mocha";
    accent = "mauve";
    cursors = {
      enable = true;
      flavor = "mocha";
      accent = "mauve";
    };
  };

  gtk = {
    enable = true;
    theme = {
      name = "catppuccin-mocha-mauve-standard";
      package = pkgs.catppuccin-gtk.override {
        variant = "mocha";
        accents = ["mauve"];
      };
    };
  };

  programs.kitty = {
    enable = true;
    keybindings = {
      "ctrl+shift+e" = "launch --location=vsplit --cwd=current";
      "ctrl+shift+o" = "launch --location=hsplit --cwd=current";
      "alt+left" = "neighboring_window left";
      "alt+right" = "neighboring_window right";
      "alt+up" = "neighboring_window up";
      "alt+down" = "neighboring_window down";
      "ctrl+left" = "resize_window narrower";
      "ctrl+right" = "resize_window wider";
      "ctrl+up" = "resize_window taller";
      "ctrl+down" = "resize_window shorter";
      "ctrl+home" = "resize_window reset";
    };
    settings = {
      allow_remote_control = "yes";
      enabled_layouts = "splits";
      scrollback_lines = -1;
      wheel_scroll_multiplier = 5;
      touch_scroll_multiplier = 5;
      confirm_os_window_close = 0;
    };
  };

  dconf.settings = {
    "org/gnome/mutter" = {
      dynamic-workspaces = false;
      experimental-features = ["scale-monitor-framebuffer"];
    };
    "org/gnome/desktop/wm/preferences" = {
      button-layout = "appmenu:minimize,maximize,close";
      num-workspaces = lib.hm.gvariant.mkInt32 1;
    };
    "org/gnome/desktop/wm/keybindings" = {
      move-to-workspace-down = [""];
      move-to-workspace-up = [""];
      switch-to-workspace-down = [""];
      switch-to-workspace-up = [""];
    };
    "org/gnome/nautilus/preferences" = {
      default-folder-viewer = "list-view";
    };
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      enable-hot-corners = false;
      show-battery-percentage = true;
    };
    "org/gnome/desktop/calendar" = {
      show-weekdate = true;
    };
    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [
        "dash-to-dock@micxgx.gmail.com"
        "appindicatorsupport@rgcjonas.gmail.com"
        "HeadsetControl@lauinger-clan.de"
      ];
      favorite-apps = [
        "org.mozilla.firefox.desktop"
        "org.gnome.Nautilus.desktop"
        "com.rtosta.zapzap.desktop"
        "kitty.desktop"
      ];
    };
    "org/gnome/shell/extensions/HeadsetControl" = {
      headsetcontrol-executable = lib.getExe pkgs.headsetcontrol;
    };
    "org/gnome/shell/extensions/dash-to-dock" = {
      apply-custom-theme = true;
      autohide = true;
      background-opacity = 0.8;
      click-action = "focus-or-previews";
      custom-theme-shrink = false;
      dash-max-icon-size = 48;
      disable-overview-on-startup = true;
      dock-position = "LEFT";
      dock-fixed = false;
      height-fraction = 0.9;
      intellihide = true;
      intellihide-mode = "FOCUS_APPLICATION_WINDOWS";
      middle-click-action = "launch";
      preferred-monitor = -2;
      preferred-monitor-by-connector = "HDMI-1";
      scroll-action = "cycle-windows";
      shift-click-action = "minimize";
      shift-middle-click-action = "launch";
      show-trash = true;
      show-mounts = true;
    };
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
      ];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name = "Launch Kitty";
      command = "kitty";
      binding = "<Primary><Alt>t";
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "org.mozilla.firefox.desktop";
      "x-scheme-handler/about" = "org.mozilla.firefox.desktop";
      "x-scheme-handler/http" = "org.mozilla.firefox.desktop";
      "x-scheme-handler/https" = "org.mozilla.firefox.desktop";
      "x-scheme-handler/unknown" = "org.mozilla.firefox.desktop";
    };
  };
}
