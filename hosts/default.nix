{
  white-tower = {
    systemProfiles = ["impermanence-root" "llama-cpp" "nvidia"];
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
    ];
  };

  pbovbel-dell = {
    systemProfiles = ["impermanence-root" "nvidia"];
    users = [
      {
        name = "pbovbel";
        systemModule = ../users/pbovbel.nix;
        profiles = ["work"];
      }
    ];
  };

  # media = {
  #   systemProfiles = ["headless"];
  #   users = [
  #     {
  #       name = "pbovbel";
  #       systemModule = ../users/pbovbel.nix;
  #       profiles = ["headless"];
  #     }
  #   ];
  # };
}
