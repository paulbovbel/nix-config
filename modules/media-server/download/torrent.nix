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
  config = lib.mkIf cfg.downloads.enable {
    age.secrets = {
      pia-env.file = ../../../secrets/server/pia-env.age;
      web-credentials-env.file = ../../../secrets/server/web-credentials-env.age;
    };

    storage.datasets.app.children = {
      autobrr = {};
      qbittorrent = {};
      unpackerr = {};
      jackett = {};
      prowlarr = {};
    };

    systemd = {
      services = {
        cleanup-downloads = {
          description = "Remove torrent downloads older than ${toString cleanupDownloadsAgeDays} days";
          serviceConfig.Type = "oneshot";
          path = [pkgs.findutils];
          script = ''
            find ${datasets.downloads.path}/torrents -maxdepth 1 -mtime +${toString cleanupDownloadsAgeDays} -exec rm -rf {} \;
          '';
        };

        qbittorrent-config = {
          description = "Render qBittorrent WebUI configuration before container startup";
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
        description = "Schedule removal of old torrent downloads";
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
        prowlarr = {
          quadlet.containerConfig = {
            image = "lscr.io/linuxserver/prowlarr";
            environments = {
              PUID = toString user.uid;
              PGID = toString user.gid;
              TZ = config.time.timeZone;
              PROWLARR__SERVER__URLBASE = "/prowlarr";
            };
            volumes = ["${datasets.app.children.prowlarr.path}:/config"];
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
            memory = "12g";
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
            image = "docker.io/golift/unpackerr:latest";
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

    caddy.sites.media.endpoints = {
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

      prowlarr = {
        type = "proxy";
        auth = "oauth";
        path = "/prowlarr";
        host = "prowlarr";
        port = 9696;
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
