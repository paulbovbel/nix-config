{
  pkgs,
  quadlet-nix,
  agenix,
}: let
  image = pkgs.dockerTools.buildLayeredImage {
    name = "podman-exposure-test";
    tag = "latest";
    contents = [pkgs.python3];
    config.Cmd = ["${pkgs.python3}/bin/python3" "-m" "http.server" "8000"];
  };
in
  pkgs.testers.runNixOSTest {
    name = "podman-server-exposure";
    nodes.machine = {lib, ...}: {
      imports = [../../documentation/options.nix quadlet-nix.nixosModules.quadlet agenix.nixosModules.default ../default.nix ../../upnp ../../storage/options.nix];
      options.rootFs.persistDirectories = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
      config = {
        _module.args = {
          lanAddressCommand = "printf 192.0.2.1";
          lanNetworkCommand = "printf 192.0.2.0/24";
        };
        users.users.pbovbel.isNormalUser = true;
        services.tailscale.interfaceName = "tailnet-test";
        environment.systemPackages = [pkgs.curl pkgs.iproute2];
        podmanServer.containers = {
          exposed = {
            ports = [
              {
                hostPort = 8080;
                containerPort = 8000;
                exposure = ["tailnet"];
              }
            ];
            quadlet.containerConfig.image = "docker-archive:${image}";
          };
          internal.quadlet.containerConfig.image = "docker-archive:${image}";
        };
        virtualisation.memorySize = 2048;
        virtualisation.diskSize = 4096;
        system.stateVersion = "26.05";
      };
    };
    testScript = builtins.readFile ./exposure.py;
  }
