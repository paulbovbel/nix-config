{ config, pkgs, unstablePkgs, ... }:

{
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

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "root" "pbovbel" ];
  nix.settings.substituters = [
    "https://cache.nixos.org"
    "https://paulbovbel.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbOJTs4f2vT5M9T8qN9kYChdD4="
    "paulbovbel.cachix.org-1:9WWi/8x8my7+Hs6/ZmuYCBU3guG1zw7da/4nkZ+vViQ="
  ];
  nix.settings.post-build-hook = pkgs.writeShellScript "cachix-push" ''
    ${pkgs.cachix}/bin/cachix push paulbovbel "$OUT_PATHS" || true
  '';

  age.secrets.cachix-auth-token = {
    file = ../../secrets/common/cachix-auth-token.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  systemd.services.cachix-auth = {
    description = "Configure Cachix auth token";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" "agenix.service" ];
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

  services.openssh.enable = true;
  services.openssh.settings = {
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

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    (_: prev: {
      openldap = prev.openldap.overrideAttrs {
        doCheck = !prev.stdenv.hostPlatform.isi686;
      };
    })
  ];

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
}
