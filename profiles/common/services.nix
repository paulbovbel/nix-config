{
  config,
  pkgs,
  ...
}: let
  inhibitSleepWhileSshScript = ./inhibit-sleep-while-ssh.sh;
in {
  systemd.services = {
    inhibit-sleep-while-ssh = {
      description = "Prevent system sleep while interactive SSH sessions are active";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      path = [pkgs.systemd pkgs.bash pkgs.procps pkgs.coreutils pkgs.gnugrep];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = 5;
        ExecStart = "${pkgs.bash}/bin/bash ${inhibitSleepWhileSshScript}";
      };
    };
  };

  networking = {
    resolvconf.enable = false;
  };

  services = {
    fwupd.enable = true;

    resolved = {
      enable = true;
      settings.Resolve.ResolveUnicastSingleLabel = true;
    };

    openssh = {
      enable = true;
      settings = {
        Port = 22;
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        PermitEmptyPasswords = false;
        StrictModes = true;
        IgnoreRhosts = true;
        UsePAM = true;
        KbdInteractiveAuthentication = false;
        X11Forwarding = false;
      };
      hostKeys = [
        {
          path = "${config.rootFs.persistPath}/etc/ssh/ssh_host_rsa_key";
          type = "rsa";
          bits = 4096;
        }
        {
          path = "${config.rootFs.persistPath}/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];
    };
  };

  rootFs.persistDirectories = [
    "/var/lib/fwupd"
  ];
}
