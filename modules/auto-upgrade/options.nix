{lib, ...}: {
  options.autoUpgrade = {
    enable = lib.mkEnableOption "guarded automatic NixOS upgrades";

    repository = lib.mkOption {
      type = lib.types.str;
      default = "ssh://git@github.com/paulbovbel/nix-config.git";
      description = "Git repository containing the system flake.";
    };

    branch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Fallback branch for generations that do not record their source branch.";
    };

    email = lib.mkOption {
      type = lib.types.str;
      default = "paul@bovbel.com";
      description = "Recipient for automatic upgrade reports.";
    };
  };
}
