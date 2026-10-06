{lib}:
lib.types.submodule {
  options = {
    title = lib.mkOption {
      type = lib.types.str;
      description = "Documentation page title.";
    };
    summary = lib.mkOption {
      type = lib.types.str;
      description = "Short description for the module index.";
    };
    category = lib.mkOption {
      type = lib.types.enum (import ./categories.nix);
      description = "Documentation sidebar category.";
    };
  };
}
