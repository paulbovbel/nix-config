{
  system = "x86_64-linux";
  # useUnstablePackages = true;
  users = [
    {
      name = "pbovbel";
      profiles = ["gaming"];
    }
    {
      name = "rbovbel";
      profiles = ["graphical"];
    }
    {
      name = "abovbel";
      profiles = ["gaming"];
    }
  ];
}
