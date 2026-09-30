{
  config,
  lib,
  ...
}: let
  cfg = config.mediaServer;
  datasets = config.storage.datasets;
  audiobookshelfPath = datasets.app.children.audiobookshelf.path;
  inherit (config.podmanServer) user;
in {
  config = lib.mkIf cfg.library.enable {
    age.secrets.web-credentials-env.file = ../../../secrets/server/web-credentials-env.age;

    storage.datasets = {
      downloads = {};
      app.children = {
        audiobookshelf = {};
        grimmory = {};
        grimmory-db = {};
      };
    };

    systemd.tmpfiles.rules = [
      "d ${audiobookshelfPath}/config 0755 ${user.name} ${user.group} - -"
      "d ${audiobookshelfPath}/metadata 0755 ${user.name} ${user.group} - -"
      "d ${datasets.downloads.path}/bookdrop 0775 ${user.name} ${user.group} - -"
    ];

    podmanServer = {
      derivedEnvFiles = {
        grimmory = {
          secretEnvironmentFiles = [config.age.secrets.web-credentials-env.path];
          variables = {
            DATABASE_USERNAME = "$WEB_USER";
            DATABASE_PASSWORD = "$WEB_PASSWORD";
          };
        };

        grimmory-db = {
          secretEnvironmentFiles = [config.age.secrets.web-credentials-env.path];
          variables = {
            MYSQL_ROOT_PASSWORD = "$WEB_PASSWORD";
            MYSQL_USER = "$WEB_USER";
            MYSQL_PASSWORD = "$WEB_PASSWORD";
          };
        };
      };

      containers = {
        audiobookshelf = {
          quadlet.containerConfig = {
            image = "ghcr.io/advplyr/audiobookshelf:latest";
            podmanArgs = ["--user=${toString user.uid}:${toString user.gid}"];
            environments = {
              PORT = "8000";
              TZ = config.time.timeZone;
            };
            volumes = [
              "${audiobookshelfPath}/config:/config"
              "${audiobookshelfPath}/metadata:/metadata"
              "${datasets.media.children.audiobooks.path}:/audiobooks"
            ];
          };
        };

        grimmory-db = {
          quadlet.containerConfig = {
            image = "lscr.io/linuxserver/mariadb:11.4.8";
            environments = {
              MYSQL_DATABASE = "booklore";
              PGID = toString user.gid;
              PUID = toString user.uid;
              TZ = config.time.timeZone;
            };
            volumes = ["${datasets.app.children."grimmory-db".path}:/config"];
          };
          derivedEnvironmentFiles = ["grimmory-db"];
        };

        grimmory = {
          dependsOn = ["grimmory-db"];
          quadlet.containerConfig = {
            image = "ghcr.io/paulbovbel/grimmory:preview-240cc39";
            environments = {
              USER_ID = toString user.uid;
              GROUP_ID = toString user.gid;
              TZ = config.time.timeZone;
              DATABASE_URL = "jdbc:mariadb://grimmory-db:3306/booklore";
              FORCE_DISABLE_OIDC = "false";
              REMOTE_AUTH_ENABLED = "true";
              REMOTE_AUTH_CREATE_NEW_USERS = "true";
              REMOTE_AUTH_HEADER_USER = "X-Token-User-Email";
              REMOTE_AUTH_HEADER_NAME = "X-Token-User-Name";
              REMOTE_AUTH_HEADER_EMAIL = "X-Token-User-Email";
              REMOTE_AUTH_HEADER_GROUPS = "X-Token-User-Roles";
              REMOTE_AUTH_ADMIN_GROUP = "admin";
              BASE_PATH = "/grimmory";
            };
            volumes = [
              "${datasets.app.children.grimmory.path}:/app/data"
              "${datasets.media.children.books.path}:/books"
              "${datasets.media.children.comics.path}:/comics"
              "${datasets.downloads.path}/bookdrop:/bookdrop"
            ];
          };
          derivedEnvironmentFiles = ["grimmory"];
        };
      };
    };

    caddy = {
      sites = {
        kobo = {
          domains = [
            {
              host = "${config.networking.hostName}.${config.networking.domain}";
              listenPort = 8443;
            }
          ];
          endpoints.grimmory-kobo = {
            type = "proxy";
            auth = null;
            path = "/grimmory/api/kobo";
            host = "grimmory";
            port = 6060;
            headerUp = [
              "X-Forwarded-Proto https"
              "X-Forwarded-Host ${config.networking.hostName}.${config.networking.domain}"
              "X-Forwarded-Port 8443"
            ];
          };
        };

        media.endpoints.audiobookshelf = {
          type = "proxy";
          # Use the application's login so native streaming clients can authenticate.
          auth = "oauth";
          path = "/audiobookshelf";
          host = "audiobookshelf";
          port = 8000;
          role = "user";
        };

        media.endpoints.grimmory = {
          type = "proxy";
          auth = "oauth";
          path = "/grimmory";
          host = "grimmory";
          port = 6060;
          role = "user";
        };
      };
    };

    upnp.forwards.kobo = lib.mkIf cfg.upnp.enable {
      from = 8443;
      to = 8443;
      proto = "tcp";
    };
  };
}
