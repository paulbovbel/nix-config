{
  lib,
  options,
  ...
}: let
  quadletContainerType = options.virtualisation.quadlet.containers.type.nestedTypes.elemType;
  quadletBuildType = options.virtualisation.quadlet.builds.type.nestedTypes.elemType;
  containerType = lib.types.submodule {
    options = {
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
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = "pbovbel";
      };
      uid = lib.mkOption {
        type = lib.types.int;
        default = 1000;
      };
      gid = lib.mkOption {
        type = lib.types.int;
        default = 1000;
      };
    };

    paths = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Shared Podman server filesystem paths.";
    };

    containers = lib.mkOption {
      type = lib.types.attrsOf containerType;
      default = {};
      description = "Containers rendered as Podman Quadlet units.";
    };

    derivedEnvFiles = lib.mkOption {
      type = lib.types.attrsOf derivedEnvFileType;
      default = {};
      description = "Runtime-rendered environment files declared by Podman server fragments.";
    };
  };
}
