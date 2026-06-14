{lib, ...}: let
  containerType = lib.types.submodule {
    options = {
      image = lib.mkOption {
        type = lib.types.str;
        description = "Container image to run.";
      };

      environment = lib.mkOption {
        type = lib.types.attrsOf (lib.types.oneOf [lib.types.str lib.types.int lib.types.bool]);
        default = {};
        description = "Container environment variables.";
      };

      environmentFiles = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Environment files passed to the container.";
      };

      secretEnvironmentFiles = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Secret environment files passed to the container.";
      };

      derivedEnvironmentFiles = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Keys from podmanServer.derivedEnvFiles passed to the container.";
      };

      ports = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Published ports in host:container[/proto] form.";
      };

      volumes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Container volume mounts.";
      };

      tmpfs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Tmpfs mounts.";
      };

      devices = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Device mappings.";
      };

      capabilities = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional capabilities.";
      };

      sysctls = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Container sysctls.";
      };

      dependsOn = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Other container names this one depends on.";
      };

      unitRequires = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional systemd units required by this container.";
      };

      unitAfter = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional systemd units this container starts after.";
      };

      requiresMountsFor = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Host paths that must be mounted before starting.";
      };

      command = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Container command.";
      };

      execStopPre = lib.mkOption {
        type = lib.types.nullOr lib.types.lines;
        default = null;
        description = "Commands to run before container shutdown.";
      };

      privileged = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Run the container privileged.";
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
