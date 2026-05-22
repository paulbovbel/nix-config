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

  users.users.deploy = {
    isNormalUser = true;
    description = "Deployment user";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC1WGjxe/6kJ2uHiI1R85VifWC2GeaEj98sAZIMLtFqgqY8zASg7in+We4oE/H1xBPf9AXHwM03rNTNQyVQ/w+YRacPAiRI8w6/tnx+ry/atxwZjFuGgYvzJockc1ar3zGSa3TWWUqe85TfwB6YjbQtSqqvGQ+BWI44+nsbKgGtFzyVyBBhdYmuBcVkNi9rCATRtto4rmBEs9RfHvWb+dLXMdUZbo4DsYZanMiucbWkrq4soHVZKJWGMqBmVRwVsO+pm9FyE3p1EaRh5afILCKi0X3X3jdJUrWIqqn7SiqaQCrx4uotpQef0S45eJhl2AqwpB66OnngMfhB4xaO+wgBEpjOheLLcfnFCH9WXEmD6r49om91K22+8j20Y93zNeDoYC6OYxe0flAzdsTbyfyx2lo2/TdNzYc5ruqgNbnhDnbeZJ2JLx3CbpixxGZJU9BhG2Pye+dpgnLTT48jEX5L/kWQMNkD50mpIEbFK8zLASH5g1q5bvw0NuTrpN8u2FqCmPEvpybFOTw1lV13I0l2fCdHSw3RNPA3QSP/GeGbOkx7yGWH2wJxJTGr1up2FBp7S6uCqU7MlVlrRbSzyKEmH5cTTFho+CnAhr1lQtlajCRTwm5UuoQYLFYkT/J+1lcXqU40H7jKYqRdwgVZ5CL6smJ/9IuZiJY2CA3rmcrPFQ== paul@bovbel.com"
    ];
  };

  security.sudo.extraRules = [
    {
      users = [ "deploy" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

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
