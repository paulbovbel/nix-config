{lib, ...}: {
  options.gameStreaming = {
    enable = lib.mkEnableOption "Sunshine game streaming with the shared application menu";
    encoder = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum ["nvenc" "vaapi" "software"]);
      default = null;
      description = "Sunshine encoder, or null for automatic selection. Selecting nvenc also enables CUDA support in the Sunshine package.";
    };
  };
}
