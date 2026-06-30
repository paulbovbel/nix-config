{
  # useUnstablePackages = true;
  users = [
    {
      name = "pbovbel";
      systemModule = ../../users/pbovbel.nix;
      profiles = ["gaming"];
    }
    {
      name = "rbovbel";
      systemModule = ../../users/rbovbel.nix;
      profiles = ["graphical"];
    }
    {
      name = "abovbel";
      systemModule = ../../users/abovbel.nix;
      profiles = ["gaming"];
    }
  ];
}
