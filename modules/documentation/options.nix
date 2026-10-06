{lib, ...}: {
  options.moduleDocumentation = lib.mkOption {
    internal = true;
    default = {};
    type = lib.types.attrsOf (import ./metadata-type.nix {inherit lib;});
    description = "Module documentation metadata.";
  };
}
