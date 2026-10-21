{
  catppuccin,
  vscode-workspace-populator,
  overlays,
  configurationBranch,
  configurationRevision,
  containerImages,
  name,
  users,
  unstablePkgs,
}: {
  config,
  lib,
  ...
}: let
  configuredUserNames = map (user: user.name) users;
  hiddenUserNames = map (user: user.name) (builtins.filter (user: user.hideFromLogin or false) users);
  trustEnvironment = {
    SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    REQUESTS_CA_BUNDLE = "/etc/ssl/certs/ca-certificates.crt";
    UV_SYSTEM_CERTS = "true";
    # Replace Node's bundled roots rather than extending them.
    NODE_OPTIONS = "--use-openssl-ca";
  };
  catppuccinPaletteSource = let
    source = (lib.importJSON "${catppuccin}/pkgs/sources.json").palette;
  in
    (builtins.fetchTree {
      type = "github";
      owner = "catppuccin";
      repo = "palette";
      inherit (source) rev;
      narHash = source.hash;
    }).outPath;
in {
  assertions = [
    {
      assertion = config.networking.hostName == name;
      message = "Host ${name} configures networking.hostName as ${config.networking.hostName}";
    }
  ];
  rootFs.homeUsers = configuredUserNames;
  system.configurationRevision = configurationRevision;
  environment.etc."nix-config/branch".text = configurationBranch;
  # eMudhra intermediate CA compromise (October 2026), including cross-signs.
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
    "emSign ECC Root CA - G3"
  ];
  # Share the system trust policy with interactive clients and background units.
  environment.sessionVariables = trustEnvironment;
  systemd.globalEnvironment = trustEnvironment;
  accounts = lib.genAttrs configuredUserNames (_: {enable = true;});
  services.displayManager.gdm.settings = lib.mkIf (hiddenUserNames != []) {
    greeter.Exclude = lib.concatStringsSep "," hiddenUserNames;
  };
  # Avoid building a target-platform package for TTY colors during evaluation.
  catppuccin.sources.palette = catppuccinPaletteSource;
  nixpkgs = {
    inherit overlays;
    config.allowUnfree = true;
  };
  home-manager = {
    backupFileExtension = "backup";
    useGlobalPkgs = true;
    useUserPackages = true;
    sharedModules = [catppuccin.homeModules.catppuccin];
    extraSpecialArgs = {inherit unstablePkgs vscode-workspace-populator containerImages;};
  };
}
