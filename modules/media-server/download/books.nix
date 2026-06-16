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

      services = let
        mkMamUpdate = {
          container,
          iface,
          mamIdVariable,
        }: {
          description = "Update myanonamouse for ${container}";
          wants = ["network-online.target" "${container}.service"];
          after = ["network-online.target" "${container}.service"];
          path = [pkgs.bash pkgs.coreutils pkgs.podman];
          serviceConfig = {
            Type = "oneshot";
            EnvironmentFile = config.age.secrets.mam-id-env.path;
            ExecStart = "${pkgs.bash}/bin/bash ${mamIpUpdate} ${user.name} ${user.group} ${container} ${iface} ${mamIdVariable}";
          };
        };
      in {
        myanonamouse-deluge = mkMamUpdate {
          container = "deluge";
          iface = "wg0";
          mamIdVariable = "MAM_ID_DELUGE";
        };

        myanonamouse-jackett = mkMamUpdate {
          container = "jackett";
          iface = "eth0";
          mamIdVariable = "MAM_ID_JACKETT";
        };
      };

      timers = let
        mkMamTimer = service: {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = mamCalendar;
            Persistent = true;
            Unit = service;
          };
        };
      in {
        myanonamouse-deluge = mkMamTimer "myanonamouse-deluge.service";
        myanonamouse-jackett = mkMamTimer "myanonamouse-jackett.service";
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
