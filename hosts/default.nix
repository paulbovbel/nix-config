let
  publicDomain = "bovbel.com";
  tailscaleDomain = "axolotl-vibe.ts.net";
in {
  white-tower = {
    inherit publicDomain tailscaleDomain;
    # useUnstablePackages = true;
    users = [
      {
        name = "pbovbel";
        systemModule = ../users/pbovbel.nix;
        profiles = ["gaming"];
      }
      {
        name = "rbovbel";
        systemModule = ../users/rbovbel.nix;
        profiles = ["graphical"];
      }
      {
        name = "abovbel";
        systemModule = ../users/abovbel.nix;
        profiles = ["gaming"];
      }
    ];
  };

  pbovbel-dell = {
    inherit publicDomain tailscaleDomain;
    users = [
      {
        name = "pbovbel";
        systemModule = ../users/pbovbel.nix;
        profiles = ["work"];
      }
    ];
  };

  media = {
    inherit publicDomain tailscaleDomain;
    users = [
      {
        name = "pbovbel";
        systemModule = ../users/pbovbel.nix;
        profiles = ["headless"];
      }
    ];
  };
}
