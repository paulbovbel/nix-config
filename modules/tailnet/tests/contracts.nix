{pkgs}: let
  inherit (pkgs) lib;
  policy = {
    tagOwners."tag:test" = [];
    grants = [
      {
        src = ["existing"];
        dst = ["tag:test"];
        ip = ["tcp:22"];
      }
    ];
    nodeAttrs = [
      {
        target = ["tag:test"];
        attr = ["example"];
      }
    ];
    tests = [
      {
        src = "tag:test";
        deny = ["tag:test:23"];
      }
    ];
  };
  port = protocol: hostPort: count: exposure: {inherit protocol hostPort count exposure;};
  nixosConfigurations.test.config = {
    tailnet.tags = ["tag:test"];
    podmanServer.containers = {
      game.ports = [
        (port "udp" 2456 2 ["tailnet"])
        (port "tcp" 25565 1 ["tailnet" "wan"])
        (port "tcp" 9000 1 ["wan"])
        (port "udp" 2456 2 ["tailnet"])
      ];
      private.ports = [(port "tcp" 9001 1 [])];
    };
  };
  entry = {
    host = "test";
    containers = ["game"];
    grant = {
      src = ["autogroup:shared"];
      dst = ["tag:test"];
    };
  };
  generate = overrides:
    import ../policy.nix ({
        inherit lib policy nixosConfigurations;
        containerGrants = [entry];
      }
      // overrides);
  output = generate {};
  fails = overrides: !(builtins.tryEval (builtins.deepSeq (generate overrides) true)).success;
in
  assert output == policy // {grants = policy.grants ++ [(entry.grant // {ip = ["udp:2456-2457" "tcp:25565"];})];};
  assert (generate {containerGrants = [(entry // {containers = ["private"];})];}) == policy;
  assert fails {containerGrants = [(entry // {host = "missing";})];};
  assert fails {containerGrants = [(entry // {containers = ["typo"];})];};
  assert fails {policy = policy // {tagOwners = {};};};
  assert fails {containerGrants = [(entry // {grant = entry.grant // {ip = ["*"];};})];};
    pkgs.writeText "tailnet-policy-contracts" "passed\n"
