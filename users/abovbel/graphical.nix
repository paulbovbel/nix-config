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
}
