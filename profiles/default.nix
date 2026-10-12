{
  base = {
    title = "Base";
    extends = [];
    systemModule = ./base/system.nix;
    summary = "Shared system and command-line baseline";
    homeModule = {
      pbovbel = ./base/home/pbovbel.nix;
      rbovbel = ./base/home/rbovbel.nix;
      abovbel = ./base/home/abovbel.nix;
    };
  };
  graphical = {
    title = "Graphical";
    extends = ["base"];
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
