{
  lib,
  options,
  ...
}: let
  quadletContainerType = options.virtualisation.quadlet.containers.type.nestedTypes.elemType;
  quadletBuildType = options.virtualisation.quadlet.builds.type.nestedTypes.elemType;
  portType = lib.types.submodule ({config, ...}: {
    options = {
      hostPort = lib.mkOption {
        type = lib.types.port;
        description = "First port to bind on the host.";
      };
      containerPort = lib.mkOption {
        type = lib.types.port;
        default = config.hostPort;
        defaultText = lib.literalExpression "config.hostPort";
        description = "First destination port in the container.";
      };
      count = lib.mkOption {
        type = lib.types.ints.between 1 65535;
        default = 1;
        description = "Number of consecutive host and container ports to publish.";
      };
      bindAddress = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Host IP address to bind, or null for all interfaces. Write IPv6 addresses without brackets.";
      };
      protocol = lib.mkOption {
        type = lib.types.enum ["tcp" "udp"];
        default = "tcp";
        description = "Transport protocol to publish.";
      };
      exposure = lib.mkOption {
        type = lib.types.listOf (lib.types.enum ["tailnet" "wan"]);
        default = [];
        description = "Direct host access scopes. Tailnet opens ports on the Tailscale interface; WAN opens ports globally and always requests UPnP forwards. Declare both to express both access intents. An empty list publishes without opening the firewall. Omit ports entirely for container-internal access.";
      };
    };
  });
  containerType = lib.types.submodule {
    options = {
      ports = lib.mkOption {
        type = lib.types.listOf portType;
        default = [];
        description = "Structured published ports with firewall and UPnP policy. Raw quadlet.containerConfig.publishPorts remain supported but do not generate firewall rules or UPnP forwards.";
      };
      build = lib.mkOption {
        type = lib.types.nullOr quadletBuildType;
        default = null;
        description = "quadlet-nix build module for this container. When set, the container image uses the generated build ref.";
      };

      quadlet = lib.mkOption {
        type = quadletContainerType;
        default = {};
        description = "quadlet-nix container module merged with Podman server defaults.";
      };

      dependsOn = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Other Podman server container names this one requires and starts after.";
      };

      secretEnvironmentFiles = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Secret environment files appended to containerConfig.environmentFiles.";
      };

      derivedEnvironmentFiles = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Keys from podmanServer.derivedEnvFiles appended to containerConfig.environmentFiles.";
      };
    };
  };

  derivedEnvFileType = lib.types.submodule ({name, ...}: {
    options = {
      path = lib.mkOption {
        type = lib.types.str;
        default = "/run/podman-server/${name}.env";
        description = "Path to the rendered environment file.";
      };

      environmentFiles = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Source environment files used while rendering.";
      };

      secretEnvironmentFiles = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Secret source environment files used while rendering.";
      };

      derivedEnvironmentFiles = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Keys from podmanServer.derivedEnvFiles used while rendering.";
      };

      variables = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        description = "Environment variables to write. Values may reference source variables with shell syntax.";
      };

      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [];
        description = "Packages available while rendering.";
      };

      createIfMissing = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Only render the environment file when it does not already exist.";
      };

      directoryMode = lib.mkOption {
        type = lib.types.str;
        default = "0755";
        description = "Permissions for the rendered environment file directory.";
      };

      wants = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Systemd units wanted by the renderer.";
      };

      after = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Systemd units the renderer starts after.";
      };

      mode = lib.mkOption {
        type = lib.types.str;
        default = "0600";
        description = "Permissions for the rendered environment file.";
      };
    };
  });
in {
  options.podmanServer = {
    user = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "pbovbel";
        description = "Host user that owns rootless Podman containers and application paths.";
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = "pbovbel";
        description = "Host group that owns rootless Podman containers and application paths.";
      };
      uid = lib.mkOption {
        type = lib.types.int;
        default = 1000;
        description = "Numeric host user ID mapped into Podman server containers.";
      };
      gid = lib.mkOption {
        type = lib.types.int;
        default = 1000;
        description = "Numeric host group ID mapped into Podman server containers.";
      };
    };

    paths = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Named host filesystem paths shared with service modules and container declarations.";
    };

    networkInterface = lib.mkOption {
      type = lib.types.str;
      default = "podman-apps";
      description = "Host interface name of the shared Podman applications network.";
    };

    containers = lib.mkOption {
      type = lib.types.attrsOf containerType;
      default = {};
      example = lib.literalExpression ''
        {
          example = {
            ports = [{ hostPort = 8080; containerPort = 80; exposure = [ "tailnet" ]; }];
            quadlet.containerConfig = {
              image = "docker.io/library/nginx:latest";
            };
            dependsOn = [ "database" ];
          };
        }
      '';
      description = "Named container declarations rendered as Podman Quadlet systemd units.";
    };

    derivedEnvFiles = lib.mkOption {
      type = lib.types.attrsOf derivedEnvFileType;
      default = {};
      description = "Named environment files rendered at runtime from public and agenix-managed inputs.";
    };
  };
}
