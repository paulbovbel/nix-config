{lib, ...}: {
  options.accounts = lib.genAttrs ["pbovbel" "rbovbel" "abovbel"] (user: {
    isKid = lib.mkOption {
      type = lib.types.bool;
      default = user == "abovbel";
      description = "Whether ${user} is a child account. Selected child accounts make graphical hosts restricted kids tailnet devices.";
    };
  });
}
