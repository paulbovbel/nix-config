_: {
  imports = [
    ../../common/home/abovbel.nix
    ../home.nix
    ../avatar.nix
  ];

  bovbel.avatar = {
    enable = true;
    source = ../../../assets/avatars/abovbel.png;
    fileName = "abovbel-avatar.png";
  };

  bovbel.background = {
    enable = true;
    source = ../../../assets/wallpapers/abovbel-hogwarts-harry.jpg;
    fileName = "abovbel-hogwarts-harry.jpg";
  };
}
