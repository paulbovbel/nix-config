{lib, ...}: {
  options.accounts = lib.mapAttrs (user: account: {
    isKid = lib.mkOption {
      type = lib.types.bool;
      default = account.isKid;
      description = "Whether ${user} is a child account. Selected child accounts make graphical hosts restricted kids tailnet devices.";
    };
  }) (import ./registry.nix);
}
