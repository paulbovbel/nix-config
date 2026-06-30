{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mediaServer;
  datasets = config.storage.datasets;
  inherit (config.podmanServer) user;
  containerUser = "${toString user.uid}:${toString user.gid}";
  mamUpdateDeps = ["network-online.target" "qbittorrent.service" "jackett.service"];
  mamUpdateRotateDeps = mamUpdateDeps ++ ["autobrr.service"];
  mamUpdate = pkgs.writeTextFile {
    name = "mam-update.py";
    executable = true;
    text = builtins.readFile ./mam-update.py;
  };
  mamUpdateCommand = lib.escapeShellArgs [
    "${pkgs.python3}/bin/python3"
    mamUpdate
    "--container-user"
    containerUser
    "--qbittorrent-config-dir"
    config.storage.datasets.app.children.qbittorrent.path
    "--jackett-config-dir"
    config.storage.datasets.app.children.jackett.path
  ];
in {
  config = lib.mkIf cfg.downloads.enable {
    age.secrets.mam-id-env.file = ../../../secrets/server/mam-id-env.age;

    storage.datasets.app.children = {
      readarr = {};
      shelfmark = {};
    };

    systemd = {
      tmpfiles.rules = [
        "d ${datasets.downloads.path}/bookdrop 0775 ${user.name} ${user.group} - -"
      ];

      services = {
        myanonamouse-update = {
          description = "Update MyAnonamouse egress IPs";
          wants = mamUpdateDeps;
          after = mamUpdateDeps;
          path = [pkgs.podman];
          serviceConfig = {
            Type = "oneshot";
            EnvironmentFile = config.age.secrets.mam-id-env.path;
            ExecStart = mamUpdateCommand;
          };
        };

        myanonamouse-update-on-switch = {
          description = "Update MyAnonamouse integrations after configuration changes";
          wantedBy = ["multi-user.target"];
          wants = mamUpdateRotateDeps;
          after = mamUpdateRotateDeps;
          path = [pkgs.podman];
          restartTriggers = [config.age.secrets.mam-id-env.file mamUpdate];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            EnvironmentFile = config.age.secrets.mam-id-env.path;
            ExecStart = "${mamUpdateCommand} --rotate-app-configs";
          };
        };
      };

      timers.myanonamouse-update = {
        description = "Schedule MyAnonamouse egress IP updates";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "hourly";
          Persistent = true;
          Unit = "myanonamouse-update.service";
        };
      };
    };

    podmanServer.containers = {
      readarr = {
        dependsOn = ["jackett"];
        quadlet.containerConfig = {
          image = "lscr.io/linuxserver/readarr:0.4.18-develop";
          environments = {
            PUID = toString user.uid;
            PGID = toString user.gid;
            TZ = config.time.timeZone;
          };
          volumes = [
            "/etc/localtime:/etc/localtime:ro"
            "${datasets.app.children.readarr.path}:/config"
            "${datasets.downloads.path}:/downloads"
            "${datasets.media.children.books.path}:/books"
            "${datasets.media.children.audiobooks.path}:/audiobooks"
          ];
        };
      };

      shelfmark = {
        quadlet.containerConfig = {
          image = "ghcr.io/calibrain/shelfmark:latest";
          environments = {
            PUID = toString user.uid;
            PGID = toString user.gid;
            TZ = config.time.timeZone;
          };
          volumes = [
            "${datasets.downloads.path}/bookdrop:/cwa-book-ingest"
            "${datasets.app.children.shelfmark.path}:/config"
          ];
        };
      };
    };

    caddy.sites.media.endpoints = {
      readarr = {
        type = "proxy";
        auth = "oauth";
        path = "/readarr";
        host = "readarr";
        port = 8787;
        role = "admin";
        spoofBasic = true;
      };

      shelfmark = {
        type = "proxy";
        auth = "oauth";
        path = "/shelfmark";
        host = "shelfmark";
        port = 8084;
        role = "admin";
      };
    };
  };
}
