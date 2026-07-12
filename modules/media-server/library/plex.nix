{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mediaServer;
  datasets = config.storage.datasets;
  inherit (config.podmanServer) user;
  devisualizeScript = pkgs.writeTextFile {
    name = "devisualize";
    destination = "/bin/devisualize";
    executable = true;
    text = builtins.readFile ./devisualize.py;
  };
  shufflePlexCollectionsScript = pkgs.writeTextFile {
    name = "shuffle-plex-collections";
    destination = "/bin/shuffle-plex-collections";
    executable = true;
    text = builtins.readFile ./shuffle-plex-collections.py;
  };
  python = pkgs.python3.withPackages (ps: [ps.plexapi]);
  devisualizeConfig = {
    calendar = "daily";
  };
  shufflePlexCollectionsConfig = {
    calendar = "daily";
    collections = ["Keepers"];
  };
in {
  config = lib.mkIf cfg.library.enable {
    age.secrets.plex-token-env.file = ../../../secrets/server/plex-token-env.age;

    storage.datasets.app.children = {
      plex = {};
      tautulli = {};
    };

    podmanServer = {
      derivedEnvFiles.plex = {
        derivedEnvironmentFiles = ["lan"];
        mode = "0644";
        variables.ADVERTISE_IP = "http://$LAN_ADDRESS:32400/";
      };

      containers = {
        plex = {
          quadlet.containerConfig = {
            image = "docker.io/plexinc/pms-docker:plexpass";
            publishPorts = ["32400:32400"];
            volumes = [
              "${datasets.app.children.plex.path}:/config"
              "${datasets.media.path}:/mnt/storage/share:ro"
            ];
            tmpfses = ["/transcode"];
            devices = ["/dev/dri:/dev/dri"];
            environments = {
              PLEX_UID = toString user.uid;
              PLEX_GID = toString user.gid;
              TZ = config.time.timeZone;
            };
          };
          derivedEnvironmentFiles = ["plex"];
        };

        tautulli = {
          dependsOn = ["plex"];
          quadlet.containerConfig = {
            image = "lscr.io/linuxserver/tautulli:latest";
            environments = {
              PUID = toString user.uid;
              PGID = toString user.gid;
              TZ = config.time.timeZone;
            };
            volumes = [
              "${datasets.app.children.tautulli.path}:/config"
              "${datasets.app.children.plex.path}/Library/Application Support/Plex Media Server/Logs:/logs:ro"
            ];
          };
        };

        plex-mcp = {
          dependsOn = ["plex"];
          secretEnvironmentFiles = [config.age.secrets.plex-token-env.path];
          quadlet.containerConfig = {
            image = "ghcr.io/astral-sh/uv:python3.13-bookworm";
            publishPorts = ["3001:3001"];
            environments = {
              PLEX_URL = "http://plex:32400";
              UV_LINK_MODE = "copy";
            };
            exec = [
              "uvx"
              "plex-mcp-server"
              "--transport"
              "sse"
              "--host"
              "0.0.0.0"
              "--port"
              "3001"
            ];
          };
        };
      };
    };

    caddy.sites.media.endpoints.tautulli = {
      type = "proxy";
      auth = "oauth";
      path = "/tautulli";
      host = "tautulli";
      port = 8181;
      role = "admin";
    };

    systemd = {
      services.devisualize = {
        description = "Extract configured Plex collections to audio files";
        wants = ["apps-network.service" "plex.service"];
        after = ["apps-network.service" "plex.service"];
        path = [pkgs.ffmpeg];
        serviceConfig = {
          Type = "oneshot";
          User = user.name;
          Group = user.group;
          EnvironmentFile = config.age.secrets.plex-token-env.path;
        };
        script = ''
          ${python}/bin/python ${devisualizeScript}/bin/devisualize \
            --host-media-root ${lib.escapeShellArg datasets.media.path}
        '';
      };

      services.shuffle-plex-collections = {
        description = "Shuffle Plex Watchlist collection order";
        wants = ["apps-network.service" "plex.service"];
        after = ["apps-network.service" "plex.service"];
        serviceConfig = {
          Type = "oneshot";
          User = user.name;
          Group = user.group;
          EnvironmentFile = config.age.secrets.plex-token-env.path;
        };
        script = ''
          ${python}/bin/python ${shufflePlexCollectionsScript}/bin/shuffle-plex-collections \
            ${lib.escapeShellArgs shufflePlexCollectionsConfig.collections}
        '';
      };

      timers.devisualize = {
        description = "Schedule Plex collection audio extraction";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = devisualizeConfig.calendar;
          Persistent = true;
        };
      };

      timers.shuffle-plex-collections = {
        description = "Schedule Plex Watchlist collection shuffling";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = shufflePlexCollectionsConfig.calendar;
          Persistent = true;
        };
      };
    };

    upnp.forwards.plex = lib.mkIf cfg.upnp.enable {
      from = 32400;
      to = 32400;
      proto = "tcp";
    };
  };
}
