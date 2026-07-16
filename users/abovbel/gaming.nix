_: {
  imports = [
    ./graphical.nix
    ../common/gaming.nix
  ];

  dconf.settings."org/gnome/shell".favorite-apps = [
    "steam.desktop"
  ];
}
