{
  config,
  graphicalSessions,
  lib,
  pkgs,
  unstablePkgs,
  ...
}: let
  cfg = config.llamaCpp;
  llamaProxy = ./llama-proxy.py;
in {
  options.moduleDocumentation.llama-cpp = lib.mkOption {
    internal = true;
    readOnly = true;
    default = {
      title = "llama.cpp";
      summary = "Locally hosted llama.cpp inference service.";
    };
  };

  options.llamaCpp.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable the llama.cpp proxy service.";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      # Pin llama.cpp to unstable for newer CUDA support than stable.
      (unstablePkgs.llama-cpp.override {cudaSupport = true;})
    ];

    networking.firewall.allowedTCPPorts = [11434];

    systemd.tmpfiles.rules = [
      "d /var/lib/llama-cpp 0755 root root -"
      "d /var/lib/llama-cpp/hf-cache 0755 root root -"
    ];

    systemd.services.llama-cpp-proxy = {
      description = "Proxy server is always-on, model server is started lazily on demand.";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      path = [
        pkgs.systemd
        graphicalSessions
        pkgs.bash
        pkgs.coreutils
        pkgs.gnugrep
        (unstablePkgs.llama-cpp.override {cudaSupport = true;})
        pkgs.python3Packages.huggingface-hub
        pkgs.python3Packages.hf-xet
      ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 5;
        User = "root";
        Group = "root";
        ExecStart = ''
          ${pkgs.python3.withPackages (ps: [ps.aiohttp ps.huggingface-hub ps.hf-xet])}/bin/python ${llamaProxy}
        '';
        Environment = [
          "HF_HOME=/var/lib/llama-cpp/hf-cache"
          "HF_HUB_DISABLE_PROGRESS_BARS=0"
          "HF_HUB_DISABLE_XET=1"
        ];
        WorkingDirectory = "/var/lib/llama-cpp";
      };
    };
    rootFs.persistDirectories = [
      "/var/lib/llama-cpp"
    ];
  };
}
