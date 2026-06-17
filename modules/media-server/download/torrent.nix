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
  qbittorrentConfigFile = "${datasets.app.children.qbittorrent.path}/qBittorrent/config/qBittorrent.conf";
  qbittorrentConfigScript = pkgs.writeShellScript "qbittorrent-config" (builtins.readFile ./qbittorrent-config.sh);
  cleanupDownloadsAgeDays = 60;
  cleanupDownloadsCalendar = "04:30";
in {
  config = lib.mkIf (cfg.enable && cfg.components.downloads.enable) {
    age.secrets = {
      pia-env.file = ../../../secrets/server/pia-env.age;
      web-credentials-env.file = ../../../secrets/server/web-credentials-env.age;
    };

    storage.datasets.app.children = {
      autobrr = {};
      qbittorrent = {};
      unpackerr = {};
      jackett = {};
    };

    systemd = {
      services = {
        cleanup-downloads = {
          description = "Cleanup old downloads from ${datasets.downloads.path}";
          serviceConfig.Type = "oneshot";
          path = [pkgs.findutils];
          script = ''
            find ${datasets.downloads.path}/torrents -maxdepth 1 -mtime +${toString cleanupDownloadsAgeDays} -exec rm -rf {} \;
          '';
        };

        qbittorrent-config = {
          description = "Configure qBittorrent WebUI settings";
          wants = ["apps-network.service"];
          after = ["apps-network.service"];
          before = ["qbittorrent.service"];
          path = [pkgs.coreutils pkgs.crudini pkgs.jq pkgs.podman];
          serviceConfig.Type = "oneshot";
          script = ''
            ${qbittorrentConfigScript} ${lib.escapeShellArgs [qbittorrentConfigFile (toString user.uid) (toString user.gid)]}
          '';
        };

        qbittorrent.restartTriggers = [
          qbittorrentConfigScript
        ];
      };

      timers.cleanup-downloads = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = cleanupDownloadsCalendar;
          Persistent = true;
        };
      };
    };

    podmanServer = {
      derivedEnvFiles.qbittorrent = {
        derivedEnvironmentFiles = ["lan"];
        secretEnvironmentFiles = [config.age.secrets.pia-env.path];
        variables = {
          VPN_USER = "$PIA_USERNAME";
          VPN_PASS = "$PIA_PASSWORD";
          LAN_NETWORK = "$LAN_NETWORK,$TAILSCALE_NETWORK";
        };
      };

      containers = {
        jackett = {
          quadlet.containerConfig = {
            image = "lscr.io/linuxserver/jackett";
            environments = {
              PUID = toString user.uid;
              PGID = toString user.gid;
              TZ = config.time.timeZone;
            };
            volumes = ["${datasets.app.children.jackett.path}:/config"];
          };
        };

        qbittorrent = {
          quadlet.unitConfig = {
            Requires = ["qbittorrent-config.service"];
            After = ["qbittorrent-config.service"];
          };
          quadlet.containerConfig = {
            image = "ghcr.io/binhex/arch-qbittorrentvpn:latest";
            sysctl."net.ipv4.conf.all.src_valid_mark" = "1";
            addCapabilities = ["NET_ADMIN"];
            volumes = [
              "/etc/localtime:/etc/localtime:ro"
              "${datasets.app.children.qbittorrent.path}:/config"
              "${datasets.downloads.path}:/downloads"
            ];
            environments = {
              PUID = toString user.uid;
              PGID = toString user.gid;
              TZ = config.time.timeZone;
              STRICT_PORT_FORWARD = "yes";
              NAME_SERVERS = "8.8.8.8,8.8.4.4";
              VPN_ENABLED = "yes";
              VPN_PROV = "pia";
              VPN_CLIENT = "wireguard";
              VPN_REMOTE_SERVER = "ca-toronto.privacy.network";
            };
            podmanArgs = ["--privileged"];
          };
          derivedEnvironmentFiles = ["qbittorrent"];
          secretEnvironmentFiles = [config.age.secrets.web-credentials-env.path];
        };

        autobrr = {
          quadlet.containerConfig = {
            image = "ghcr.io/autobrr/autobrr:latest";
            user = containerUser;
            environments.TZ = config.time.timeZone;
            volumes = ["${datasets.app.children.autobrr.path}:/config"];
          };
        };

        flaresolverr = {
          quadlet.containerConfig = {
            image = "ghcr.io/flaresolverr/flaresolverr:latest";
            environments = {
              PUID = toString user.uid;
              PGID = toString user.gid;
              TZ = config.time.timeZone;
              CAPTCHA_SOLVER = "none";
            };
          };
        };

        unpackerr = {
          quadlet.containerConfig = {
            image = "golift/unpackerr";
            user = containerUser;
            environments.TZ = config.time.timeZone;
            volumes = [
              "${datasets.downloads.path}:/downloads"
              "${datasets.app.children.unpackerr.path}:/config"
            ];
          };
        };
      };
    };

    caddy.endpoints = {
      autobrr = {
        type = "proxy";
        auth = "oauth";
        path = "/autobrr";
        host = "autobrr";
        port = 7474;
        role = "admin";
      };

      jackett = {
        type = "proxy";
        auth = "oauth";
        path = "/jackett";
        host = "jackett";
        port = 9117;
        role = "admin";
      };

      qbittorrent = {
        type = "proxy";
        auth = "oauth";
        path = "/qbittorrent";
        host = "qbittorrent";
        port = 8080;
        role = "admin";
        handlePath = true;
      };
    };
  };
}
