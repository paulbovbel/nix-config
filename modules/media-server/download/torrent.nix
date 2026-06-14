{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mediaServer;
  datasets = config.storage.datasets;
  inherit (config.podmanServer) user;
  cleanupDownloadsAgeDays = 60;
  cleanupDownloadsCalendar = "04:30";
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
          image = "lscr.io/linuxserver/jackett";
          environment = {
            PUID = user.uid;
            PGID = user.gid;
            TZ = config.time.timeZone;
          };
          volumes = ["${datasets.app.children.jackett.path}:/config"];
          requiresMountsFor = ["/storage"];
        };

        deluge = {
          image = "binhex/arch-delugevpn";
          privileged = true;
          sysctls = ["net.ipv4.conf.all.src_valid_mark=1"];
          capabilities = ["NET_ADMIN"];
          ports = ["58846:58846"];
          volumes = [
            "/etc/localtime:/etc/localtime:ro"
            "${datasets.app.children.deluge.path}:/config"
            "${datasets.downloads.path}:/downloads"
          ];
          environment = {
            PUID = user.uid;
            PGID = user.gid;
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
          derivedEnvironmentFiles = ["deluge"];
          secretEnvironmentFiles = [config.age.secrets.web-credentials-env.path];
          execStopPre = "${pauseTorrents} deluge";
          requiresMountsFor = ["/storage"];
        };

        autobrr = {
          image = "ghcr.io/autobrr/autobrr:latest";
          environment.TZ = config.time.timeZone;
          volumes = ["${datasets.app.children.autobrr.path}:/config"];
          requiresMountsFor = ["/storage"];
        };

        flaresolverr = {
          image = "ghcr.io/flaresolverr/flaresolverr:latest";
          environment = {
            PUID = user.uid;
            PGID = user.gid;
            TZ = config.time.timeZone;
            CAPTCHA_SOLVER = "none";
          };
        };

        unpackerr = {
          image = "golift/unpackerr";
          environment.TZ = config.time.timeZone;
          volumes = [
            "${datasets.downloads.path}:/downloads"
            "${datasets.app.children.unpackerr.path}:/config"
          ];
          requiresMountsFor = ["/storage"];
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
