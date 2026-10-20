{
  config,
  lib,
  pkgs,
  osConfig,
  graphicalShell,
  caelestia-shell,
  caelestia-dots,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) system;
  cli = caelestia-shell.inputs.caelestia-cli.packages.${system}.default;
  shell =
    (caelestia-shell.packages.${system}.with-cli.override {
      inherit (pkgs) hyprland;
    }).overrideAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          cp ${pkgs.writeText "caelestia-pam-passwd" "auth include caelestia\n"} assets/pam.d/passwd
          substituteInPlace assets/pam.d/fprint \
            --replace-fail /run/current-system/sw/lib/security/pam_fprintd.so ${pkgs.fprintd}/lib/security/pam_fprintd.so
        '';
    });
  # Retain upstream window listeners, while Home Manager owns session startup.
  execsParts = lib.splitString "-- Resizer listeners" (builtins.readFile "${caelestia-dots}/hypr/hyprland/execs.lua");
  initCaelestia = pkgs.writeShellApplication {
    name = "init-caelestia";
    runtimeInputs = [cli];
    text = builtins.readFile ./home/scripts/init-caelestia.sh;
  };
in {
  config = lib.mkIf (graphicalShell == "hyprland") {
    assertions = [
      {
        assertion = builtins.length execsParts == 2;
        message = "Caelestia's startup layout changed; review the session startup adapter.";
      }
    ];

    programs.caelestia = {
      enable = true;
      package = shell;
      systemd.target = "hyprland-session.target";
      settings = {
        general = {
          apps = {
            terminal = ["kitty"];
            audio = ["pavucontrol"];
            explorer = ["nautilus"];
          };
          idle.timeouts = [
            {
              timeout = 900;
              idleAction = "lock";
            }
            {
              timeout = 1200;
              idleAction = "dpms off";
              returnAction = "dpms on";
            }
          ];
        };
        paths.wallpaperDir = "${config.home.homeDirectory}/.local/share/backgrounds";
        lock = {
          enableFprint = osConfig.services.fprintd.enable;
          enableHowdy = false;
        };
      };
      cli = {
        enable = true;
        package = cli;
        settings = {
          theme = {
            enableGtk = false;
            enableQt = false;
            enableTerm = false;
            enableChromium = false;
          };
          toggles = {
            communication.discord.command = ["flatpak" "run" "com.discordapp.Discord"];
            music.spotify.command = ["flatpak" "run" "com.spotify.Client"];
            sysmon.btop.command = ["kitty" "--class" "btop" "--title" "btop" "btop"];
            todo.todoist.enable = false;
          };
        };
      };
    };

    wayland = {
      systemd.target = "hyprland-session.target";
      windowManager.hyprland = {
        enable = true;
        package = null;
        portalPackage = null;
        configType = "lua";
        systemd = {
          enable = true;
          enableXdgAutostart = true;
        };
        extraConfig = builtins.readFile "${caelestia-dots}/hypr/hyprland.lua";
      };
    };
    catppuccin.hyprland.enable = false;

    home = {
      packages = [pkgs.btop pkgs.hyprpicker pkgs.pavucontrol pkgs.wl-clipboard pkgs.ydotool];
      file.".face".source = config.bovbel.avatar.source;
      sessionVariables.CAELESTIA_WALLPAPERS_DIR = "${config.home.homeDirectory}/.local/share/backgrounds";
    };

    xdg.configFile =
      (lib.mapAttrs' (name: _:
        lib.nameValuePair "hypr/hyprland/${name}" {
          source = "${caelestia-dots}/hypr/hyprland/${name}";
        })
      (builtins.readDir "${caelestia-dots}/hypr/hyprland"))
      // {
        "hypr/variables.lua".source = "${caelestia-dots}/hypr/variables.lua";
        "hypr/utils".source = "${caelestia-dots}/hypr/utils";
        "hypr/scheme/default.lua".source = "${caelestia-dots}/hypr/scheme/default.lua";
        "hypr/hyprland/execs.lua".text = ''
          local fn = require("utils.functions")
          -- Resizer listeners
          ${builtins.elemAt execsParts 1}
        '';
        "hypr/hyprland/keybinds.lua".text =
          lib.replaceStrings
          ["qs -c caelestia kill; sleep .1; caelestia shell -d" "qs -c caelestia kill"]
          ["systemctl --user restart caelestia.service" "systemctl --user stop caelestia.service"]
          (builtins.readFile "${caelestia-dots}/hypr/hyprland/keybinds.lua");
        "caelestia/hypr-vars.lua".text =
          "return "
          + lib.generators.toLua {} {
            terminal = "kitty";
            browser = "flatpak run org.mozilla.firefox";
            editor = "code";
            fileExplorer = "nautilus";
            audioSettings = "pavucontrol";
            cursorTheme = config.home.pointerCursor.name or "Adwaita";
            cursorSize = config.home.pointerCursor.size or 24;
          };
        "caelestia/hypr-user.lua".text = ''
          hl.config({ input = {
            kb_layout = ${builtins.toJSON osConfig.services.xserver.xkb.layout},
            kb_variant = ${builtins.toJSON osConfig.services.xserver.xkb.variant},
          } })
          hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
        '';
      };

    services = {
      cliphist = {
        enable = true;
        allowImages = true;
        systemdTargets = ["hyprland-session.target"];
      };
      hyprpolkitagent.enable = true;
      mpris-proxy.enable = true;
    };
    systemd.user.services.caelestia.Service.ExecStartPre = "${lib.getExe initCaelestia} ${config.bovbel.background.source}";
  };
}
