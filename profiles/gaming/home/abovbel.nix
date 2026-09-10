_: {
  imports = [
    ../../graphical/home/abovbel.nix
    ../home.nix
  ];

  dconf.settings."org/gnome/shell".favorite-apps = [
    "steam.desktop"
  ];
}
