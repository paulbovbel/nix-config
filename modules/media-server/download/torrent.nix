{
  config,
  containerImages,
  lib,
  pia-wg-config,
  pkgs,
  ...
}: let
  cfg = config.mediaServer;
  datasets = config.storage.datasets;
  inherit (config.podmanServer) user;
  containerUser = "${toString user.uid}:${toString user.gid}";
  qbittorrentProfile = datasets.app.children.qbittorrent.path;
  gluetunDirectory = datasets.app.children.gluetun.path;
  storageUnits = lib.optional config.storage.enable "zfs-mount.service";
  qbittorrentConfigFile = "${qbittorrentProfile}/qBittorrent/qBittorrent.conf";
  qbittorrentConfigScript = pkgs.writeShellApplication {
    name = "qbittorrent-config";
    runtimeInputs = [pkgs.coreutils pkgs.crudini pkgs.jq pkgs.podman];
    text = builtins.readFile ./scripts/qbittorrent-config.sh;
  };
  piaDirectory = "/run/pia-wireguard";
  piaLeaseGuard = pkgs.writeShellApplication {
    name = "pia-lease-guard";
    runtimeInputs = [pkgs.coreutils];
    text = builtins.readFile ./scripts/pia-lease-guard.sh;
  };
  # The pinned fork requires Go 1.27; use unstable only for this package.
  piaWgConfig = pia-wg-config.packages.${pkgs.stdenv.hostPlatform.system}.default;
  portSyncScript = pkgs.writeTextFile {
    name = "qbittorrent-port-sync";
    destination = "/app/port-sync.py";
    text = builtins.readFile ./scripts/qbittorrent-port-sync.py;
  };
  portSyncImage = pkgs.dockerTools.buildLayeredImage {
    name = "localhost/qbittorrent-port-sync";
    contents = [pkgs.python3 portSyncScript];
    config = {
      Cmd = ["${pkgs.python3}/bin/python3" "/app/port-sync.py"];
      User = "65534:65534";
      Env = ["PYTHONDONTWRITEBYTECODE=1" "PYTHONUNBUFFERED=1"];
    };
  };
  gluetunControlAuth = pkgs.writeText "gluetun-port-sync-auth.toml" ''
    [[roles]]
    name = "port-sync"
    routes = ["GET /v1/portforward"]
    auth = "none"
  '';
  # Podman rejects --dns when joining another container's network namespace, so
  # point the namespace sharers at Gluetun's resolver by file instead.
  torrentResolvConf = pkgs.writeText "qbittorrent-resolv.conf" "nameserver 127.0.0.1\n";
  cleanupDownloadsAgeDays = 60;
  cleanupDownloadsCalendar = "04:30";
in {
  config = lib.mkIf cfg.downloads.enable {
    age.secrets.pia-env.file = ../../../secrets/server/pia-env.age;

    storage.datasets.app.children = {
      autobrr = {};
      qbittorrent = {};
      gluetun = {
        owner = "root";
        group = "root";
        mode = "0700";
      };
      unpackerr = {};
      jackett = {};
      prowlarr = {};
    };

    systemd = {
      services = {
        pia-wireguard-config = {
          description = "Register an ephemeral PIA WireGuard key";
          wants = ["network-online.target"];
          # The lease marker lives in Gluetun's dataset, so it must be mounted.
          after = ["network-online.target"] ++ storageUnits;
          requires = storageUnits;
          restartTriggers = [config.age.secrets.pia-env.file piaWgConfig piaLeaseGuard];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            EnvironmentFile = config.age.secrets.pia-env.path;
            RuntimeDirectory = "pia-wireguard";
            RuntimeDirectoryMode = "0700";
            UMask = "0077";
            TimeoutStartSec = 240;
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            # The generator prints the WireGuard config; keep it out of the journal.
            StandardOutput = "null";
            ExecStart = "${piaWgConfig}/bin/pia-wg-config --region ca_toronto --outfile ${piaDirectory}/wg0.conf --server-name-file ${piaDirectory}/server-name";
            ExecStartPost = "${piaLeaseGuard}/bin/pia-lease-guard ${piaDirectory}/server-name ${gluetunDirectory}";
            ReadWritePaths = [gluetunDirectory];
          };
        };

        cleanup-downloads = {
          description = "Remove torrent downloads older than ${toString cleanupDownloadsAgeDays} days";
          serviceConfig.Type = "oneshot";
          path = [pkgs.findutils];
          script = ''
            find ${datasets.downloads.path}/torrents -maxdepth 1 -mtime +${toString cleanupDownloadsAgeDays} -exec rm -rf {} \;
          '';
        };
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
      derivedEnvFiles.gluetun = {
        path = "${piaDirectory}/gluetun.env";
        directoryMode = "0700";
        # Ordering alone is insufficient: never render from stale files after
        # failed provisioning. Gluetun pulls this renderer in on each startup.
        requires = ["pia-wireguard-config.service"];
        after = ["pia-wireguard-config.service"];
        secretEnvironmentFiles = [config.age.secrets.pia-env.path];
        variables = {
          VPN_PORT_FORWARDING_USERNAME = "$PIA_USERNAME";
          VPN_PORT_FORWARDING_PASSWORD = "$PIA_PASSWORD";
          SERVER_NAMES = "$(cat ${piaDirectory}/server-name)";
        };
      };
      containers = {
        gluetun = {
          quadlet = {
            unitConfig = {
              Requires = ["pia-wireguard-config.service"];
              After = ["pia-wireguard-config.service"];
              PartOf = ["pia-wireguard-config.service"];
            };
            containerConfig = {
              image = containerImages.gluetun;
              addCapabilities = ["NET_ADMIN"];
              devices = ["/dev/net/tun:/dev/net/tun"];
              # Gluetun runs privileged for NET_ADMIN and owns this directory as
              # root, so PUID/PGID are deliberately left unset.
              volumes = [
                "${gluetunDirectory}:/gluetun"
                "${piaDirectory}:/pia-wireguard"
                "${gluetunControlAuth}:/gluetun/auth/config.toml:ro"
              ];
              environments = {
                TZ = config.time.timeZone;
                VPN_SERVICE_PROVIDER = "custom";
                VPN_TYPE = "wireguard";
                VPN_INTERFACE = "wg0";
                WIREGUARD_CONF_SECRETFILE = "/pia-wireguard/wg0.conf";
                VPN_PORT_FORWARDING = "on";
                VPN_PORT_FORWARDING_PROVIDER = "private internet access";
                HTTP_CONTROL_SERVER_ADDRESS = "127.0.0.1:8000";
                # qBittorrent's WebUI port, reached in-namespace rather than
                # published, so nothing derives it. Keep both in step.
                FIREWALL_INPUT_PORTS = "8080";
              };
            };
          };
          derivedEnvironmentFiles = ["gluetun"];
        };
        qbittorrent-port-sync = {
          networkNamespaceOf = "gluetun";
          quadlet.containerConfig = {
            image = "docker-archive:${portSyncImage}";
            readOnly = true;
            noNewPrivileges = true;
            dropCapabilities = ["ALL"];
          };
        };
        jackett = {
          quadlet.containerConfig = {
            image = containerImages.jackett;
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
            image = containerImages.prowlarr;
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
          networkNamespaceOf = "gluetun";
          quadlet = {
            serviceConfig.ExecStartPre = ["${qbittorrentConfigScript}/bin/qbittorrent-config ${lib.escapeShellArgs [qbittorrentConfigFile (toString user.uid) (toString user.gid)]}"];
            containerConfig = {
              image = containerImages.qbittorrent;
              volumes = [
                "/etc/localtime:/etc/localtime:ro"
                "${torrentResolvConf}:/etc/resolv.conf:ro"
                "${qbittorrentProfile}:/config"
                "${datasets.downloads.path}:/downloads"
              ];
              environments = {
                PUID = toString user.uid;
                PGID = toString user.gid;
                TZ = config.time.timeZone;
                WEBUI_PORT = "8080";
              };
              memory = "12g";
            };
          };
        };

        autobrr = {
          quadlet.containerConfig = {
            image = containerImages.autobrr;
            user = containerUser;
            environments.TZ = config.time.timeZone;
            volumes = ["${datasets.app.children.autobrr.path}:/config"];
          };
        };

        flaresolverr = {
          quadlet.containerConfig = {
            image = containerImages.flaresolverr;
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
            image = containerImages.unpackerr;
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
        dashboard = {
          name = "autobrr";
        };
        type = "proxy";
        auth = "oauth";
        path = "/autobrr";
        host = "autobrr";
        port = 7474;
        role = "admin";
      };

      jackett = {
        dashboard = {
          name = "Jackett";
        };
        type = "proxy";
        auth = "oauth";
        path = "/jackett";
        host = "jackett";
        port = 9117;
        role = "admin";
      };

      prowlarr = {
        dashboard = {
          name = "Prowlarr";
        };
        type = "proxy";
        auth = "oauth";
        path = "/prowlarr";
        host = "prowlarr";
        port = 9696;
        role = "admin";
      };

      qbittorrent = {
        dashboard = {
          name = "qBittorrent";
        };
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
