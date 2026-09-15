{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.atticCache;
  domain = "${cfg.subdomain}.${config.networking.domain}";
  endpoint = "https://${domain}/";
  watchStore = pkgs.writeShellApplication {
    name = "attic-watch-store";
    runtimeInputs = [pkgs.attic-client pkgs.coreutils];
    text = builtins.readFile ./attic-watch-store.sh;
  };
in {
  options.moduleDocumentation.attic-cache = lib.mkOption {
    internal = true;
    readOnly = true;
    default = {
      title = "Attic Cache";
      summary = "Attic binary cache server and automatic watch-store uploads.";
    };
  };

  imports = [
    ./options.nix
    ./server.nix
  ];

  config = lib.mkIf cfg.client.enable {
    age.secrets.attic-watch-store-token.file = ../../secrets/common/attic-watch-store-token.age;

    environment.systemPackages = [pkgs.attic-client];

    systemd.services.attic-watch-store = {
      description = "Continuously upload new local Nix store paths to Attic";
      wantedBy = ["multi-user.target"];
      wants = ["agenix-install-secrets.service" "network-online.target"];
      after = ["agenix-install-secrets.service" "network-online.target" "nix-daemon.service"];
      unitConfig.ConditionPathExists = config.age.secrets.attic-watch-store-token.path;
      environment = {
        ATTIC_CACHE = "${cfg.serverName}:${cfg.cacheName}";
        ATTIC_ENDPOINT = endpoint;
        ATTIC_JOBS = toString cfg.client.jobs;
        ATTIC_SERVER_NAME = cfg.serverName;
        ATTIC_TOKEN_FILE = config.age.secrets.attic-watch-store-token.path;
        HOME = "/var/lib/attic-watch-store";
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${watchStore}/bin/attic-watch-store";
        StateDirectory = "attic-watch-store";
        Restart = "always";
        RestartSec = 30;
      };
    };
  };
}
