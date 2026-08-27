{pkgs, ...}: {
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
