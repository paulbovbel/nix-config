{
  # useUnstablePackages = true;
  users = [
    {
      name = "abovbel";
      systemModule = ../../users/abovbel.nix;
      profiles = ["gaming"];
    }
    {
      name = "pbovbel";
      systemModule = ../../users/pbovbel.nix;
      profiles = ["gaming"];
    }
  ];
}
