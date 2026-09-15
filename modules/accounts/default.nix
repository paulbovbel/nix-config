{
  lib,
  pkgs,
  ...
}: let
  graphicalSessions = pkgs.writeShellApplication {
    name = "graphical-sessions";
    runtimeInputs = [pkgs.coreutils pkgs.glib pkgs.sudo pkgs.systemd];
    text = ''
      exec ${pkgs.python3}/bin/python ${./graphical_sessions.py} "$@"
    '';
  };
in {
  options.moduleDocumentation.accounts = lib.mkOption {
    internal = true;
    readOnly = true;
    default = {
      title = "Accounts";
      summary = "Local user accounts, SSH access, and account-specific secrets.";
    };
  };

  imports = [
    ./abovbel.nix
    ./pbovbel.nix
    ./rbovbel.nix
  ];

  config._module.args = {inherit graphicalSessions;};
}
