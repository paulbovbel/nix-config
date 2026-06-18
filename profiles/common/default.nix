{
  agenix,
  config,
  lib,
  pkgs,
  ...
}: let
  cliPackages = import ./cli-packages.nix {inherit pkgs;};
  inhibitSleepWhileSshScript = ./inhibit-sleep-while-ssh.sh;
in {
  catppuccin = {
    enable = lib.mkDefault false;
    autoEnable = lib.mkDefault false;
  };

  boot = {
    # Performance-biased defaults: trades hardening for lower overhead.
    kernelParams = [
      # Disable most CPU vulnerability mitigations globally (kernel 5.2+).
      "mitigations=off"
      # Disable KPTI (Meltdown mitigation).
      "nopti"
      # Disable IBRS (Spectre v2 mitigation).
      "noibrs"
      # Disable IBPB (Spectre v2 mitigation).
      "noibpb"
      # Disable Spectre v2 mitigation paths.
      "nospectre_v2"
      # Disable Speculative Store Bypass mitigation.
      "spec_store_bypass_disable=off"
      # Disable L1TF mitigations.
      "l1tf=off"
      # Disable MDS mitigations.
      "mds=off"
    ];

    loader.systemd-boot = lib.mkIf config.boot.loader.systemd-boot.enable {
      extraFiles."EFI/netboot/netboot.xyz.efi" = pkgs.netbootxyz-efi.outPath;
      extraEntries."netboot-xyz.conf" = ''
        title netboot.xyz
        efi /EFI/netboot/netboot.xyz.efi
      '';
    };
  };

  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      trusted-users = ["root" "pbovbel"];
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://cuda-maintainers.cachix.org"
        "https://nix-cache.bovbel.com/nixos"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbOJTs4f2vT5M9T8qN9kYChdD4="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
        "nixos:pmAv4w1X/hCdM7rOjkK954hzdzEFiOgZshQmwWDpKNE="
      ];
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    optimise.automatic = true;
  };

  atticCache.client.enable = true;

  age = {
    secrets = {
      gmail-password = {
        file = ../../secrets/common/gmail-password.age;
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    identityPaths = [
      "/persist/etc/agenix/host.agekey"
    ];
  };

  systemd.services = {
    inhibit-sleep-while-ssh = {
      description = "Inhibit sleep while SSH sessions are active";
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

  time.timeZone = "America/Toronto";
  i18n.defaultLocale = "en_CA.UTF-8";

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
          path = "/persist/etc/ssh/ssh_host_rsa_key";
          type = "rsa";
          bits = 4096;
        }
        {
          path = "/persist/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];
    };

    smartd = {
      enable = true;
      defaults.autodetected = "-a -n standby,15,q -o on -S on -s (L/../../6/01|S/../.././02)";
      notifications.mail = {
        enable = true;
        sender = "paul@bovbel.com";
        recipient = "paul@bovbel.com";
      };
    };
  };

  programs.msmtp = {
    enable = true;
    defaults = {
      aliases = "/etc/aliases";
      auth = true;
      tls = true;
      tls_starttls = true;
      port = 587;
      syslog = "LOG_MAIL";
    };
    accounts.default = {
      host = "smtp.gmail.com";
      from = "paul@bovbel.com";
      user = "paul@bovbel.com";
      passwordeval = "cat ${config.age.secrets.gmail-password.path}";
    };
  };

  users.mutableUsers = false;

  security.sudo.extraConfig = ''
    Defaults lecture=never
  '';

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages =
    [
      agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
    ]
    ++ cliPackages.nixPackages
    ++ [
      pkgs.dust
      pkgs.eza
      pkgs.jless
      pkgs.just
      pkgs.procs
      pkgs.yq-go
    ];

  impermanenceRoot.persistDirectories = [
    "/var/lib/cups"
    "/var/lib/fwupd"
    "/var/lib/nixos"
    "/var/lib/systemd"
    "/var/lib/systemd/coredump"
    "/var/log"
  ];

  impermanenceRoot.persistFiles = [
    "/etc/machine-id"
  ];
}
