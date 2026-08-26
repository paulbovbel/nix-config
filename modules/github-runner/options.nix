{lib, ...}: {
  options.githubRunner = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the containerized GitHub Actions runner.";
    };

    url = lib.mkOption {
      type = lib.types.str;
      description = "GitHub repository URL to register the runner with.";
    };

    name = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "GitHub runner name; defaults to the host name.";
    };

    extraLabels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional GitHub runner labels.";
    };
  };
}
