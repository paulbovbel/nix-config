{
  config,
  pkgs,
  ...
}: let
  colors = config.lib.stylix.colors;
  rustColor = color: let
    component = offset: "0x${builtins.substring offset 2 color} as f64 / 255.0";
  in "(${component 0}, ${component 2}, ${component 4})";
  tinyDfrThemePatch = pkgs.replaceVars ./tiny-dfr.patch {
    backgroundColor = rustColor colors.base00;
    inactiveColor = rustColor colors.base02;
    activeColor = rustColor colors.base0E;
    foregroundColor = rustColor colors.base05;
    chargingColor = rustColor colors.base0B;
    lowColor = rustColor colors.base08;
  };
  nyanSprite =
    pkgs.runCommand "tiny-dfr-nyan-sprite.png" {
      nativeBuildInputs = [pkgs.imagemagick];
      src = ../../assets/tiny-dfr/nyan-cat.gif;
    } ''
      magick "$src" -coalesce -crop 220x55+1280+0 +repage \
        +append "PNG32:$out"
    '';
  tinyDfrNyanPatch = pkgs.replaceVars ./tiny-dfr-nyan.patch {
    inherit nyanSprite;
  };
in {
  nixpkgs.overlays = [
    (_final: prev: {
      tiny-dfr = prev.tiny-dfr.overrideAttrs (old: {
        patches =
          (old.patches or [])
          ++ [
            tinyDfrThemePatch
            tinyDfrNyanPatch
          ];
        postPatch =
          (old.postPatch or "")
          + ''
            substituteInPlace share/tiny-dfr/*.svg \
              --replace-quiet 'fill="white"' 'fill="#${colors.base05}"'
          '';
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
}
