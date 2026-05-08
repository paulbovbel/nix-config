{ pkgs, unstablePkgs, ... }:

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

  # TODO(pbovbel): Re-enroll during deploy by minting a short-lived auth key
  # externally, then running tailscale up over SSH to avoid persistent auth keys
  # on hosts.
  services.tailscale.enable = true;
  services.tailscale.openFirewall = true;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = [
    pkgs.bat
    pkgs.bind
    pkgs.curl
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
    pkgs.nethogs
    pkgs.ripgrep
    pkgs.tcpdump
    pkgs.tmux
    pkgs.wget
    pkgs.yq-go
    unstablePkgs.opencode
  ];
}
