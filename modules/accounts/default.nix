{pkgs, ...}: let
  graphicalSessions = pkgs.writeShellApplication {
    name = "graphical-sessions";
    runtimeInputs = [pkgs.coreutils pkgs.glib pkgs.sudo pkgs.systemd];
    text = ''
      exec ${pkgs.python3}/bin/python ${./graphical_sessions.py} "$@"
    '';
  };
in {
  imports = [
    ./abovbel.nix
    ./pbovbel.nix
    ./rbovbel.nix
  ];

  config._module.args = {inherit graphicalSessions;};
}
