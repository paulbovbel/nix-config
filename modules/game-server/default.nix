{lib, ...}: {
  options.moduleDocumentation.game-server = lib.mkOption {
    internal = true;
    readOnly = true;
    default = {
      title = "Game Server";
      summary = "Containerized Abiotic Factor, Minecraft, and Valheim servers.";
    };
  };

  imports = [
    ./options.nix
    ./abiotic.nix
    ./minecraft.nix
    ./valheim.nix
  ];
}
