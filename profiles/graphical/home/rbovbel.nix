{...}: {
  imports = [
    ./base.nix
    ../common/graphical.nix
    ../common/avatar.nix
  ];

  dconf.settings."org/gnome/shell".favorite-apps = [
    "org.mozilla.firefox.desktop"
    "org.gnome.Nautilus.desktop"
    "com.rtosta.zapzap.desktop"
    "kitty.desktop"
  ];

  bovbel.avatar = {
    enable = true;
    source = ../../assets/avatars/rbovbel.png;
    fileName = "rbovbel-avatar.png";
  };
}
