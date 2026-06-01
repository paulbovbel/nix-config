{lib, ...}: {
  imports = [
    ./base.nix
  ];

  dconf.enable = true;

  dconf.settings = {
    "org/gnome/mutter" = {
      dynamic-workspaces = false;
      experimental-features = ["scale-monitor-framebuffer"];
    };
    "org/gnome/desktop/wm/preferences" = {
      button-layout = "appmenu:minimize,maximize,close";
      num-workspaces = lib.hm.gvariant.mkInt32 1;
    };
    "org/gnome/nautilus/preferences" = {
      default-folder-viewer = "list-view";
    };
    "org/gnome/desktop/interface" = {
      gtk-theme = "Yaru";
      icon-theme = "Yaru";
      cursor-theme = "Yaru";
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
      ];
      favorite-apps = [
        "org.mozilla.firefox.desktop"
        "org.gnome.Nautilus.desktop"
        "com.rtosta.zapzap.desktop"
        "kitty.desktop"
      ];
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
      "application/json" = "code.desktop";
      "application/x-shellscript" = "code.desktop";
      "text/html" = "org.mozilla.firefox.desktop";
      "text/markdown" = "code.desktop";
      "text/plain" = "code.desktop";
      "text/x-c" = "code.desktop";
      "text/x-c++" = "code.desktop";
      "text/x-python" = "code.desktop";
      "x-scheme-handler/about" = "org.mozilla.firefox.desktop";
      "x-scheme-handler/http" = "org.mozilla.firefox.desktop";
      "x-scheme-handler/https" = "org.mozilla.firefox.desktop";
      "x-scheme-handler/unknown" = "org.mozilla.firefox.desktop";
    };
  };
}
