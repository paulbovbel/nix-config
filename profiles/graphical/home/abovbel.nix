_: {
  imports = [
    ./base.nix
    ../common/graphical.nix
    ../common/avatar.nix
  ];

  bovbel.avatar = {
    enable = true;
    source = ../../assets/avatars/abovbel.png;
    fileName = "abovbel-avatar.png";
  };

  dconf.settings."org/gnome/shell".favorite-apps = [
    "org.mozilla.firefox.desktop"
    "org.gnome.Nautilus.desktop"
  ];
}
