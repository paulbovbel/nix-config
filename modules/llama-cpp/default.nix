{ config, lib, pkgs, masterPkgs, ... }:

let
  llamaProxy = ./llama-proxy.py;
in
{
  imports = [
    ../common
  ];

  environment.systemPackages = [
    (masterPkgs.llama-cpp.override { cudaSupport = true; })
  ];

  networking.firewall.allowedTCPPorts = [ 11434 ];

  systemd.tmpfiles.rules = [
    "d /var/lib/llama-cpp 0755 root root -"
    "d /var/lib/llama-cpp/hf-cache 0755 root root -"
  ];

  systemd.services.llama-cpp-proxy = {
    description = "On-demand llama.cpp reverse proxy";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ pkgs.systemd pkgs.bash pkgs.coreutils pkgs.gnugrep
             (masterPkgs.llama-cpp.override { cudaSupport = true; })
             pkgs.python3Packages.huggingface-hub pkgs.python3Packages.hf-xet ];
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 5;
      User = "root";
      Group = "root";
      ExecStart = ''
        ${pkgs.python3.withPackages (ps: [ ps.aiohttp ps.huggingface-hub ps.hf-xet ])}/bin/python ${llamaProxy}
      '';
      Environment = [
        "HF_HOME=/var/lib/llama-cpp/hf-cache"
        "HF_HUB_DISABLE_PROGRESS_BARS=0"
        "HF_HUB_DISABLE_XET=1"
      ];
      WorkingDirectory = "/var/lib/llama-cpp";
    };
  };
}
