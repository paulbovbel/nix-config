{
  abovbel = {
    gaming = {
      graphical = true;
      homeModule = ./abovbel/gaming.nix;
      systemModules = [../profiles/gaming];
    };
  };

  pbovbel = {
    headless = {
      homeModule = ./pbovbel/headless.nix;
      systemModules = [../profiles/headless];
    };
    graphical = {
      graphical = true;
      homeModule = ./pbovbel/graphical.nix;
      systemModules = [../profiles/graphical];
    };
    work = {
      graphical = true;
      homeModule = ./pbovbel/work.nix;
      systemModules = [../profiles/work];
    };
    gaming = {
      graphical = true;
      homeModule = ./pbovbel/gaming.nix;
      systemModules = [../profiles/gaming];
    };
  };

  rbovbel = {
    graphical = {
      graphical = true;
      homeModule = ./rbovbel/graphical.nix;
      systemModules = [../profiles/graphical];
    };
  };
}
