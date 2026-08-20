{
  abovbel = {
    gaming = {
      graphical = true;
      homeModules = [./gaming/home/abovbel.nix];
      systemModules = [./gaming/system.nix];
    };
  };

  pbovbel = {
    headless = {
      homeModules = [./headless/home/pbovbel.nix];
      systemModules = [./headless/system.nix];
    };
    graphical = {
      graphical = true;
      homeModules = [./graphical/home/pbovbel.nix];
      systemModules = [./graphical/system.nix];
    };
    work = {
      graphical = true;
      homeModules = [./work/home/pbovbel.nix];
      systemModules = [./work/system.nix];
    };
    gaming = {
      graphical = true;
      homeModules = [./gaming/home/pbovbel.nix];
      systemModules = [./gaming/system.nix];
    };
  };

  rbovbel = {
    graphical = {
      graphical = true;
      homeModules = [./graphical/home/rbovbel.nix];
      systemModules = [./graphical/system.nix];
    };
  };
}
