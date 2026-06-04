{
  abovbel = {
    gaming = {
      module = ./abovbel/gaming.nix;
      systemProfile = "gaming";
    };
  };

  pbovbel = {
    headless = {
      module = ./pbovbel/headless.nix;
      systemProfile = "headless";
    };
    graphical = {
      module = ./pbovbel/graphical.nix;
      systemProfile = "graphical";
    };
    work = {
      module = ./pbovbel/work.nix;
      systemProfile = "work";
    };
    gaming = {
      module = ./pbovbel/gaming.nix;
      systemProfile = "gaming";
    };
  };

  rbovbel = {
    graphical = {
      module = ./rbovbel/graphical.nix;
      systemProfile = "graphical";
    };
  };
}
