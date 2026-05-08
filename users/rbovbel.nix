{ ... }:

{
  users.users.rbovbel = {
    isNormalUser = true;
    description = "rebecca@bovbel.com";
    extraGroups = [ "networkmanager" ];
  };
}
