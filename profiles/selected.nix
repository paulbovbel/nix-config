# Home Manager module exposing selected and inherited profiles for the user, so profile
# modules can adapt to combinations (for example gaming alongside work).
{lib, ...}: {
  options.profiles.selected = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    description = "Profile names selected for this user through NixOS userProfiles, including inherited profiles.";
  };
}
