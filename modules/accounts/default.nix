{pkgs, ...}: let
  graphicalSessions = pkgs.writeShellApplication {
    name = "graphical-sessions";
    runtimeInputs = [pkgs.coreutils pkgs.glib pkgs.sudo pkgs.systemd];
    text = ''
      exec ${pkgs.python3}/bin/python ${./scripts/graphical_sessions.py} "$@"
    '';
  };
in {
  config.moduleDocumentation.accounts = {
    title = "Accounts";
    category = "System";
    summary = "Local user accounts, SSH access, and account-specific secrets.";
  };

  imports = [
    ./abovbel.nix
    ./pbovbel.nix
    ./rbovbel.nix
  ];

  config._module.args = {inherit graphicalSessions;};
}
