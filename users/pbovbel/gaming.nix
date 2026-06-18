{lib, ...}: let
  mkAutostart = import ../common/autostart.nix;
in {
  imports = [
    ./graphical.nix
    ../common/gaming.nix
  ];

  xdg.configFile = lib.mkMerge (map mkAutostart [
    {
      file = "discord";
      name = "Discord";
      exec = "flatpak run com.discordapp.Discord";
    }
    {
      file = "whatsapp";
      name = "ZapZap";
      exec = "flatpak run com.rtosta.zapzap";
    }
  ]);
}
