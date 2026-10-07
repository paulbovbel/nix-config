{
  ageRecipient = "age17vygkuef5n8yc5ruha3punredg4gudyhpd9fwpl7zkw8q9yjveks8r6ddn";
  system = "x86_64-linux";
  installer = "generic";
  ciBuild = true;
  # useUnstablePackages = true;
  users = [
    {
      name = "abovbel";
    }
    {
      name = "pbovbel";
      hideFromLogin = true;
    }
  ];
}
