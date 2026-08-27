{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.bovbel.background;
  backgroundUri = "file://${config.home.homeDirectory}/.local/share/backgrounds/${cfg.fileName}";
  lockscreenFileName =
    if cfg.lockscreenFileName != null
    then cfg.lockscreenFileName
    else cfg.fileName;
  lockscreenSource =
    if cfg.lockscreenSource != null
    then cfg.lockscreenSource
    else cfg.source;
  lockscreenUri = "file://${config.home.homeDirectory}/.local/share/backgrounds/${lockscreenFileName}";
in {
  imports = [
    ../common/home.nix
  ];

  options.bovbel.background = {
    enable = lib.mkEnableOption "GNOME desktop and lock screen background from local assets";
    source = lib.mkOption {
      type = lib.types.path;
      description = "Desktop background image to deploy.";
    };
    fileName = lib.mkOption {
      type = lib.types.str;
      description = "Desktop background file name under ~/.local/share/backgrounds.";
    };
    lockscreenSource = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Lock screen background image to deploy. Defaults to the desktop background.";
    };
    lockscreenFileName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Lock screen background file name under ~/.local/share/backgrounds. Defaults to the desktop background file name.";
    };
  };

  config = {
    bovbel.background = {
      lockscreenSource = ../../assets/wallpapers/pbovbel-tropicanair.jpg;
      lockscreenFileName = "pbovbel-tropicanair.jpg";
    };

    dconf.enable = true;

    home.file = lib.mkIf cfg.enable (
      {
        ".local/share/backgrounds/${cfg.fileName}".source = cfg.source;
      }
      // lib.optionalAttrs (lockscreenFileName != cfg.fileName) {
        ".local/share/backgrounds/${lockscreenFileName}".source = lockscreenSource;
      }
    );

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
      "org/gnome/desktop/background" = lib.mkIf cfg.enable {
        picture-uri = backgroundUri;
        picture-uri-dark = backgroundUri;
        picture-options = "zoom";
      };
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
        switch-applications = [""];
        switch-applications-backward = [""];
        switch-to-workspace-down = [""];
        switch-to-workspace-up = [""];
        switch-windows = ["<Alt>Tab"];
        switch-windows-backward = ["<Shift><Alt>Tab"];
      };
      "org/gnome/nautilus/preferences" = {
        default-folder-viewer = "list-view";
      };
      "org/gnome/desktop/interface" = {
        enable-hot-corners = false;
        show-battery-percentage = true;
      };
      "org/gnome/desktop/calendar" = {
        show-weekdate = true;
      };
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions =
          [
            "dash-to-dock@micxgx.gmail.com"
            "appindicatorsupport@rgcjonas.gmail.com"
            "HeadsetControl@lauinger-clan.de"
          ]
          ++ lib.optionals cfg.enable ["unlockDialogBackground@sun.wxg@gmail.com"];
        favorite-apps = [
          "org.mozilla.firefox.desktop"
          "org.gnome.Nautilus.desktop"
        ];
      };
      "org/gnome/shell/extensions/unlock-dialog-background" = lib.mkIf cfg.enable {
        picture-uri = lockscreenUri;
        picture-uri-dark = lockscreenUri;
        picture-options = "zoom";
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
  };
}
