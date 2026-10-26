{
  config,
  lib,
  pkgs,
  ...
}: let
  gdmTheme = shell:
    pkgs.runCommand "gdm-tropicanair-theme.gresource" {nativeBuildInputs = [pkgs.glib];} ''
      resource=${shell}/share/gnome-shell/gnome-shell-theme.gresource
      while IFS= read -r path; do
        mkdir -p "resources$(dirname "$path")"
        gresource extract "$resource" "$path" > "resources$path"
      done < <(gresource list "$resource")
      cd resources/org/gnome/shell/theme
      cp ${../../assets/wallpapers/tropicanair.jpg} gdm-wallpaper.jpg
      for stylesheet in gnome-shell*.css; do
        test -f "$stylesheet"
        cat >> "$stylesheet" <<'EOF'
      #lockDialogGroup {
        background: #000;
      }
      .gdm-monitor-background {
        background: #000 url("gdm-wallpaper.jpg");
        background-size: cover;
        background-position: center;
        background-repeat: no-repeat;
      }
      .login-dialog { background-color: transparent; }
      EOF
      done
      {
        echo '<gresources><gresource prefix="/org/gnome/shell/theme">'
        find . -type f -printf '<file>%P</file>\n' | sort
        echo '</gresource></gresources>'
      } > ../theme.xml
      glib-compile-resources ../theme.xml --sourcedir=. --target="$out"
    '';
in {
  config = lib.mkIf (builtins.elem "graphical" config.systemProfiles) {
    # GDM's session does not reliably inherit resource-overlay environment variables.
    # Patch the packaged theme instead; the CSS targets only the login dialog.
    nixpkgs.overlays = [
      (_final: prev: let
        theme = gdmTheme prev.gnome-shell;
      in {
        gnome-shell = prev.gnome-shell.overrideAttrs (old: {
          patches = (old.patches or []) ++ [./patches/gdm-per-monitor-background.patch];
          postFixup =
            (old.postFixup or "")
            + ''
              cp ${theme} "$out/share/gnome-shell/gnome-shell-theme.gresource"
            '';
          passthru = (old.passthru or {}) // {gdmTheme = theme;};
        });
      })
    ];

    stylix = {
      enable = true;
      autoEnable = false;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
      polarity = "dark";
      targets.plymouth.enable = true;
    };

    catppuccin = {
      enable = true;
      flavor = "mocha";
      accent = "mauve";
      cursors.enable = true;
      gtk.icon.enable = true;
      plymouth.enable = false;
    };

    boot = {
      kernelParams = [
        "quiet"
        "splash"
      ];
      plymouth.enable = true;
    };

    home-manager.sharedModules = [
      {
        stylix.targets.gtk.enable = true;

        catppuccin = {
          enable = true;
          flavor = "mocha";
          accent = "mauve";
          cursors.enable = true;
          gtk.icon.enable = true;
        };
      }
    ];
  };
}
