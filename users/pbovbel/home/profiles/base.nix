{ pkgs, ... }:

{
  imports = [
    ../../../common/home/profiles/base.nix
  ];

  home.username = "pbovbel";
  home.homeDirectory = "/home/pbovbel";

  home.packages = with pkgs; [
  ];
}
