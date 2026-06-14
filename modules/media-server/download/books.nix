{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mediaServer;
  datasets = config.storage.datasets;
  inherit (config.podmanServer) user;
  mamCalendar = "hourly";
  mamIpUpdate = ./mam-ip-update.sh;
in {
  config = lib.mkIf (cfg.enable && cfg.components.downloads.enable) {
    age.secrets.mam-id-env.file = ../../../secrets/server/mam-id-env.age;

    storage.datasets.app.children = {
      readarr = {};
      shelfmark = {};
    };

    systemd = {
      tmpfiles.rules = [
        "d ${datasets.downloads.path}/bookdrop 0775 ${user.name} ${user.group} - -"
      ];

      services.myanonamouse = {
        description = "Update myanonamouse";
        wants = ["network-online.target" "agenix.service" "deluge.service" "jackett.service"];
        after = ["network-online.target" "agenix.service" "deluge.service" "jackett.service"];
        path = [pkgs.bash pkgs.coreutils pkgs.glibc.bin pkgs.podman];
        serviceConfig = {
          Type = "oneshot";
          EnvironmentFile = config.age.secrets.mam-id-env.path;
          ExecStart = "${pkgs.bash}/bin/bash ${mamIpUpdate} ${user.name} ${user.group}";
        };
      };

      timers.myanonamouse = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = mamCalendar;
          Persistent = true;
        };
      };
    };

    podmanServer.containers = {
      readarr = {
        image = "lscr.io/linuxserver/readarr:0.4.18-develop";
        dependsOn = ["jackett"];
        environment = {
          PUID = user.uid;
          PGID = user.gid;
          TZ = config.time.timeZone;
        };
        volumes = [
          "/etc/localtime:/etc/localtime:ro"
          "${datasets.app.children.readarr.path}:/config"
          "${datasets.downloads.path}:/downloads"
          "${datasets.media.children.books.path}:/books"
          "${datasets.media.children.audiobooks.path}:/audiobooks"
        ];
        requiresMountsFor = ["/storage"];
      };

      shelfmark = {
        image = "ghcr.io/calibrain/shelfmark:latest";
        environment = {
          PUID = user.uid;
          PGID = user.gid;
          TZ = config.time.timeZone;
        };
        volumes = [
          "${datasets.downloads.path}/bookdrop:/cwa-book-ingest"
          "${datasets.app.children.shelfmark.path}:/config"
        ];
        requiresMountsFor = ["/storage"];
      };
    };

    caddy.endpoints = {
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
