{
  agenix,
  lib,
  pkgs,
  ...
}: let
  cliPackages = import ./cli-packages.nix {inherit pkgs;};
in {
  time.timeZone = "America/Toronto";
  i18n.defaultLocale = "en_CA.UTF-8";

  catppuccin = {
    enable = lib.mkDefault false;
  };

  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      connect-timeout = 2;
      download-attempts = 1;
      fallback = true;
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

  atticCache.client.enable = lib.mkDefault true;

  users.mutableUsers = false;

  security.sudo.extraConfig = ''
    Defaults lecture=never
  '';

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

  age.identityPaths = [
    "/persist/etc/agenix/host.agekey"
  ];

  impermanenceRoot.persistDirectories = [
    "/var/lib/nixos"
    "/var/lib/systemd"
    "/var/lib/systemd/coredump"
    "/var/log"
  ];

  impermanenceRoot.persistFiles = [
    "/etc/machine-id"
  ];
}
