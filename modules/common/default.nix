{
  config,
  pkgs,
  unstablePkgs,
  ...
}: {
  boot.kernelParams = [
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

  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      trusted-users = ["root" "pbovbel"];
      substituters = [
        "https://cache.nixos.org"
        "https://paulbovbel.cachix.org"
        "https://nix-community.cachix.org"
        "https://cuda-maintainers.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbOJTs4f2vT5M9T8qN9kYChdD4="
        "paulbovbel.cachix.org-1:9WWi/8x8my7+Hs6/ZmuYCBU3guG1zw7da/4nkZ+vViQ="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      ];
      post-build-hook = pkgs.writeShellScript "cachix-push" ''
        ${pkgs.cachix}/bin/cachix push paulbovbel "$OUT_PATHS" || true
      '';
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    optimise.automatic = true;
  };

  age.secrets.cachix-auth-token = {
    file = ../../secrets/common/cachix-auth-token.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  systemd.services.cachix-auth = {
    description = "Configure Cachix auth token";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target" "agenix.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.cachix}/bin/cachix authtoken "$(cat ${config.age.secrets.cachix-auth-token.path})"
    '';
  };

  time.timeZone = "America/Toronto";
  i18n.defaultLocale = "en_CA.UTF-8";

  services.openssh = {
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

  users.mutableUsers = false;

  # users.users.rescue = {
  #   isNormalUser = true;
  #   description = "Temporary rescue user";
  #   extraGroups = ["wheel" "networkmanager"];
  #   password = "test";
  # };

  # services.openssh.extraConfig = ''
  #   Match User rescue
  #     PasswordAuthentication yes
  #     KbdInteractiveAuthentication yes
  #     PermitEmptyPasswords yes
  # '';

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = [
    pkgs.bat
    pkgs.bind
    pkgs.curl
    pkgs.ethtool
    pkgs.eza
    pkgs.fd
    pkgs.git
    pkgs.git-lfs
    pkgs.htop
    pkgs.iotop
    pkgs.iperf3
    pkgs.jq
    pkgs.just
    pkgs.kitty.terminfo
    pkgs.mtr
    pkgs.nettools
    pkgs.ncdu
    pkgs.nethogs
    pkgs.ripgrep
    pkgs.tcpdump
    pkgs.tmux
    pkgs.wget
    pkgs.yq-go
    unstablePkgs.opencode
  ];

  age.identityPaths = [
    "/persist/etc/agenix/host.agekey"
  ];

  impermanenceRoot.persistDirectories = [
    "/var/lib/cups"
    "/var/lib/nixos"
    "/var/lib/systemd"
    "/var/lib/systemd/coredump"
    "/var/log"
  ];

  impermanenceRoot.persistFiles = [
    "/etc/machine-id"
  ];
}
