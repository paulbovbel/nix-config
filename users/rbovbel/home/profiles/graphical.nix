{ ... }:

{
  imports = [
    ./base.nix
    ../../../common/home/profiles/graphical.nix
    ../../../common/home/profiles/gravatar-avatar.nix
  ];

  bovbel.gravatarAvatar = {
    enable = true;
    hash = "dab11c078f0b25374e70b651ed3c3b40";
    fileName = "rbovbel-gravatar.jpg";
  };
}
