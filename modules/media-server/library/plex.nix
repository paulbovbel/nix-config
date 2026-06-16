{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mediaServer;
  datasets = config.storage.datasets;
  inherit (config.podmanServer) user;
  ripToAudio = pkgs.writeScript "rip-to-audio" (builtins.readFile ./rip-to-audio.py);
  python = pkgs.python3.withPackages (ps: [ps.plexapi]);
  ripToAudioConfig = {
    calendar = "daily";
    source = "${datasets.media.children.tv.path}/Jeopardy!";
    destination = "${datasets.media.children.audiobooks.path}/Jeopardy!";
  };
in {
  config = lib.mkIf (cfg.enable && cfg.components.library.enable) {
    age.secrets.plex-token-env.file = ../../../secrets/server/plex-token-env.age;

    storage.datasets.app.children = {
      plex = {};
      tautulli = {};
    };

    podmanServer = {
      derivedEnvFiles.plex = {
        derivedEnvironmentFiles = ["lan"];
        mode = "0644";
        variables.ADVERTISE_IP = "http://$LAN_ADDRESS:50505/";
      };

      containers = {
        plex = {
          quadlet.containerConfig = {
            image = "plexinc/pms-docker:plexpass";
            publishPorts = ["50505:32400"];
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
      };
    };

    caddy.endpoints.tautulli = {
      type = "proxy";
      auth = "oauth";
      path = "/tautulli";
      host = "tautulli";
      port = 8181;
      role = "admin";
    };

    systemd = {
      services.rip-to-audio = {
        description = "Rip audio";
        wants = ["network-online.target"];
        after = ["network-online.target"];
        path = [pkgs.ffmpeg python];
        serviceConfig = {
          Type = "oneshot";
          User = user.name;
          EnvironmentFile = config.age.secrets.plex-token-env.path;
        };
        script = ''
          ${python}/bin/python ${ripToAudio} '${ripToAudioConfig.source}' '${ripToAudioConfig.destination}' "$PLEX_TOKEN"
        '';
      };

      timers.rip-to-audio = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = ripToAudioConfig.calendar;
          Persistent = true;
        };
      };
    };

    upnp.forwards.plex = lib.mkIf cfg.upnp.enable {
      from = 50505;
      to = 50505;
      proto = "tcp";
    };

    networking.firewall.allowedTCPPorts = [50505];
  };
}
