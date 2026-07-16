{
  config,
  lib,
  ...
}: let
  mkAutostart = import ./autostart.nix;
in {
  xdg.configFile = mkAutostart {
    file = "steam";
    name = "Steam";
    exec = "steam -silent";
  };

  home.activation.steamappsLibrary = lib.hm.dag.entryAfter ["writeBoundary"] ''
    steamapps_path="${config.xdg.dataHome}/Steam/steamapps"
    steamapps_target="/steam-library/${config.home.username}"

    mkdir -p "$steamapps_target"
    mkdir -p "$(dirname "$steamapps_path")"

    if [ ! -L "$steamapps_path" ] || [ "$(readlink "$steamapps_path")" != "$steamapps_target" ]; then
      rm -rf "$steamapps_path"
      ln -s "$steamapps_target" "$steamapps_path"
    fi
  '';
}
