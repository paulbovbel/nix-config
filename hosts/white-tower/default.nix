{
  ageRecipient = "age1wk8sq7rwy46a4rms25gwyvxjd0utt53l8nvwnuaujqmqj6ek5ujqjsgt8t";
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
