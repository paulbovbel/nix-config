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
  cleanupDownloadsAgeDays = 60;
  cleanupDownloadsCalendar = "04:30";
  # PR fixes the stale 7-Zip URL and Python site-packages path resolution.
  # https://github.com/binhex/arch-delugevpn/pull/446
  # A fresh build also pulls in nftables support
  # https://github.com/binhex/arch-int-vpn/pull/53
  delugeRev = "d14bf66246ff176ef07bd26f0c896c1f3c7465d6";
  delugeSrc = builtins.fetchGit {
    url = "https://github.com/partymola/arch-delugevpn.git";
    rev = delugeRev;
  };
  pauseTorrents = pkgs.writeShellScript "pause-deluge" ''
    ${lib.getExe pkgs.podman} exec "$1" /bin/bash -c 'deluge-console "connect 127.0.0.1 $WEB_USER $WEB_PASSWORD; pause *"' || true
  '';
in {
  config = lib.mkIf (cfg.enable && cfg.components.downloads.enable) {
    age.secrets = {
      pia-env.file = ../../../secrets/server/pia-env.age;
      web-credentials-env.file = ../../../secrets/server/web-credentials-env.age;
    };

    storage.datasets.app.children = {
      autobrr = {};
      deluge = {};
      unpackerr = {};
      jackett = {};
    };

    systemd = {
      services.cleanup-downloads = {
        description = "Cleanup old downloads from ${datasets.downloads.path}";
        serviceConfig.Type = "oneshot";
        path = [pkgs.findutils];
        script = ''
          find ${datasets.downloads.path}/torrents -maxdepth 1 -mtime +${toString cleanupDownloadsAgeDays} -exec rm -rf {} \;
        '';
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
      derivedEnvFiles.deluge = {
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

        deluge = {
          build.buildConfig = {
            workdir = "${delugeSrc}";
            buildArgs = {
              APPNAME = "deluge";
              RELEASETAG = "nix-${delugeRev}";
              TARGETARCH = "amd64";
            };
          };
          quadlet.containerConfig = {
            sysctl."net.ipv4.conf.all.src_valid_mark" = "1";
            addCapabilities = ["NET_ADMIN"];
            publishPorts = ["58846:58846"];
            volumes = [
              "/etc/localtime:/etc/localtime:ro"
              "${datasets.app.children.deluge.path}:/config"
              "${datasets.downloads.path}:/downloads"
            ];
            environments = {
              PUID = toString user.uid;
              PGID = toString user.gid;
              TZ = config.time.timeZone;
              STRICT_PORT_FORWARD = "yes";
              NAME_SERVERS = "8.8.8.8,8.8.4.4";
              DELUGE_DAEMON_LOG_LEVEL = "info";
              DELUGE_WEB_LOG_LEVEL = "info";
              DELUGE_ENABLE_WEBUI_PASSWORD = "no";
              VPN_ENABLED = "yes";
              VPN_PROV = "pia";
              VPN_CLIENT = "wireguard";
            };
            podmanArgs = ["--privileged"];
          };
          derivedEnvironmentFiles = ["deluge"];
          secretEnvironmentFiles = [config.age.secrets.web-credentials-env.path];
          quadlet.serviceConfig.ExecStopPre = "${pauseTorrents} deluge";
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

      deluge = {
        type = "proxy";
        auth = "oauth";
        path = "/deluge";
        host = "deluge";
        port = 8112;
        role = "admin";
        stripPrefix = true;
        headerUp = ["X-Deluge-Base \"/deluge\""];
      };

      deluge-basic = {
        type = "proxy";
        auth = "basic";
        path = "/deluge-basic";
        host = "deluge";
        port = 8112;
        stripPrefix = true;
        headerUp = ["X-Deluge-Base \"/deluge-basic\""];
      };
    };

    networking.firewall.allowedTCPPorts = [58846];
  };
}
