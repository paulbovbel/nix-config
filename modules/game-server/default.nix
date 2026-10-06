{
  config.moduleDocumentation.game-server = {
    title = "Game Server";
    category = "Applications";
    summary = "Containerized Abiotic Factor, Minecraft, and Valheim servers.";
  };

  imports = [
    ./options.nix
    ./abiotic.nix
    ./minecraft.nix
    ./valheim.nix
  ];
}
