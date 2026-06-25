{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mediaServer;
  datasets = config.storage.datasets;
  inherit (config.podmanServer) user;
  ripToAudio = pkgs.writeTextFile {
    name = "rip-to-audio";
    destination = "/bin/rip-to-audio";
    executable = true;
    text = builtins.readFile ./rip-to-audio.py;
  };
  shufflePlexCollectionsScript = pkgs.writeTextFile {
    name = "shuffle-plex-collections";
    destination = "/bin/shuffle-plex-collections";
    executable = true;
    text = builtins.readFile ./shuffle-plex-collections.py;
  };
  python = pkgs.python3.withPackages (ps: [ps.plexapi]);
  ripToAudioConfig = {
    calendar = "daily";
    shows = [
      "Jeopardy!"
      "Pop Culture Jeopardy!"
    ];
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
        variables.ADVERTISE_IP = "http://$LAN_ADDRESS:50505/";
      };

      containers = {
        plex = {
          quadlet.containerConfig = {
            image = "docker.io/plexinc/pms-docker:plexpass";
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
        description = "Extract configured Plex TV shows to audiobook audio files";
        wants = ["apps-network.service" "plex.service"];
        after = ["apps-network.service" "plex.service"];
        path = [pkgs.ffmpeg];
        serviceConfig = {
          Type = "oneshot";
          User = user.name;
          Group = user.group;
          EnvironmentFile = config.age.secrets.plex-token-env.path;
        };
        script =
          lib.concatMapStringsSep "\n" (show: ''
            ${python}/bin/python ${ripToAudio}/bin/rip-to-audio \
              '${datasets.media.children.tv.path}/${show}' \
              '${datasets.media.children.audiobooks.path}/${show}'
          '')
          ripToAudioConfig.shows;
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

      timers.rip-to-audio = {
        description = "Schedule Plex TV show audio extraction";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = ripToAudioConfig.calendar;
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
      from = 50505;
      to = 50505;
      proto = "tcp";
    };
  };
}
