{
  headless = {
    title = "Headless";
    extends = [];
    systemModule = ./headless/system.nix;
    summary = "Server and command-line environment";
    homeModule.pbovbel = ./headless/home/pbovbel.nix;
  };
  graphical = {
    title = "Graphical";
    extends = [];
    systemModule = ./graphical/system.nix;
    summary = "GNOME desktop and everyday applications";
    homeModule = {
      pbovbel = ./graphical/home/pbovbel.nix;
      rbovbel = ./graphical/home/rbovbel.nix;
    };
  };
  gaming = {
    title = "Gaming";
    extends = ["graphical"];
    systemModule = ./gaming/system.nix;
    summary = "Desktop gaming and shared game storage";
    homeModule = {
      pbovbel = ./gaming/home/pbovbel.nix;
      abovbel = ./gaming/home/abovbel.nix;
    };
  };
  work = {
    title = "Work";
    extends = ["graphical"];
    systemModule = ./work/system.nix;
    summary = "Development containers and workplace connectivity";
    homeModule.pbovbel = ./work/home/pbovbel.nix;
  };
}
