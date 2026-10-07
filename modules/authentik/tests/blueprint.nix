{
  pkgs,
  quadlet-nix,
}: let
  # Offline fixtures have independent archive hashes; refresh these pins manually.
  authentikImage = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/goauthentik/server";
    imageDigest = "sha256:ab9b4e8cc4ab3f8d1198d2db6aeea66bafea1963b3f2843589e0d163f97d9849";
    sha256 = "sha256-fA+RYsJ8eYS/bz5Rj91qcR+VIkGBealhlhbMxHCkb2A=";
    finalImageName = "ghcr.io/goauthentik/server";
    finalImageTag = "2026.8.3";
  };
  postgresImage = pkgs.dockerTools.pullImage {
    imageName = "docker.io/library/postgres";
    imageDigest = "sha256:721873c34ceb9f8d8fc265984940dc982404c105f19ad51be9fdc5970a6080ea";
    sha256 = "sha256-fjgoa8cITe7zk0N1zx7Ze1FlaEWGxqOyi8P69sE3Z2A=";
    finalImageName = "docker.io/library/postgres";
    finalImageTag = "16-alpine";
  };
in
  pkgs.testers.runNixOSTest {
    name = "authentik-blueprint";
    nodes.machine = {
      imports = [quadlet-nix.nixosModules.quadlet ./minimal.nix];
      _module.args.containerImages = {
        authentik = "docker-archive:${authentikImage}";
        postgres = "docker-archive:${postgresImage}";
      };
      virtualisation = {
        memorySize = 4096;
        cores = 2;
        diskSize = 8192;
      };
      podmanServer.containers = {
        authentik.quadlet.containerConfig.volumes = ["${./check-blueprint.py}:/tests/check-blueprint.py:ro"];
        authentik-worker.quadlet.containerConfig.volumes = ["${./wait-blueprint.py}:/tests/wait-blueprint.py:ro"];
      };
    };
    testScript = builtins.readFile ./test-script.py;
  }
