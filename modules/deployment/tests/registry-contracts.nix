let
  validateHosts = import ../../../hosts/validate.nix;
  validateProfiles = import ../../../profiles/validate.nix;
  hosts = import ../../../hosts;
  profiles = import ../../../profiles;
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  host = hosts.media;
  profile = profiles.base;
  results = {
    validHosts = validateHosts hosts == hosts;
    validProfiles = validateProfiles profiles == profiles;
    duplicateUsers = rejects (validateHosts {test = host // {users = host.users ++ host.users;};});
    unknownUsers = rejects (validateHosts {test = host // {users = [{name = "unknown";}];};});
    invalidUnstable = rejects (validateHosts {test = host // {useUnstablePackages = "yes";};});
    invalidCiBuild = rejects (validateHosts {test = host // {ciBuild = "yes";};});
    invalidInstaller = rejects (validateHosts {test = host // {installer = "unknown";};});
    invalidApplePlatform = rejects (validateHosts {test = host // {installer = "apple-silicon";};});
    invalidRecipient = rejects (validateHosts {test = host // {ageRecipient = "invalid";};});
    invalidHideFromLogin = rejects (validateHosts {
      test =
        host
        // {
          users = [
            {
              name = "pbovbel";
              hideFromLogin = "yes";
            }
          ];
        };
    });
    unknownParent = rejects (validateProfiles {base = profile // {extends = ["missing"];};});
    selfCycle = rejects (validateProfiles {base = profile // {extends = ["base"];};});
    indirectCycle = rejects (validateProfiles {
      base = profile // {extends = ["other"];};
      other = profile // {extends = ["base"];};
    });
    unknownProfileUser = rejects (validateProfiles {base = profile // {homeModule.unknown = ./registry-contracts.nix;};});
    sharedAncestor =
      builtins.deepSeq (validateProfiles {
        base = profile;
        left = profile // {extends = ["base"];};
        right = profile // {extends = ["base"];};
        leaf = profile // {extends = ["left" "right"];};
      })
      true;
  };
in
  assert builtins.all (passed: passed) (builtins.attrValues results); results
