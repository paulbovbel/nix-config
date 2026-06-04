{...}: {
  imports = [
    ./base.nix
    ../common/graphical.nix
    ../common/avatar.nix
  ];

  bovbel.avatar = {
    enable = true;
    source = ../../assets/avatars/rbovbel.png;
    fileName = "rbovbel-avatar.png";
  };
}
