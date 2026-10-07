{
  config,
  containerImages,
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

    authentik.applications = let
      baseUrl = "https://${config.networking.hostName}.${config.networking.domain}";
    in {
      audiobookshelf = {
        name = "Audiobookshelf";
        launchUrl = "${baseUrl}${config.caddy.sites.media.endpoints.audiobookshelf.path}/";
        iconUrl = config.caddy.sites.media.endpoints.audiobookshelf.dashboard.iconUrl;
        redirectUris = map (path: "${baseUrl}/audiobookshelf/auth/openid/${path}") ["callback" "mobile-redirect"];
      };
      grimmory = {
        name = "Grimmory";
        launchUrl = "${baseUrl}${config.caddy.sites.media.endpoints.grimmory.path}/";
        iconUrl = config.caddy.sites.media.endpoints.grimmory.dashboard.iconUrl;
        clientType = "public";
        redirectUris = ["${baseUrl}/grimmory/oauth2-callback"];
        scopes = ["openid" "email" "profile" "offline_access" "groups"];
        includeClaimsInIdToken = true;
      };
    };

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
            image = containerImages.audiobookshelf;
            podmanArgs = ["--user=${toString user.uid}:${toString user.gid}"];
            environments = {
              PORT = "8000";
              TZ = config.time.timeZone;
            };
            volumes = [
              "${audiobookshelfPath}/config:/config"
              "${audiobookshelfPath}/metadata:/metadata"
              "${datasets.media.children.audiobooks.path}:/audiobooks"
              "${datasets.media.children.devisualized.path}:/devisualized"
            ];
          };
        };

        grimmory-db = {
          quadlet.containerConfig = {
            image = containerImages.mariadb;
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
            image = containerImages.grimmory;
            environments = {
              USER_ID = toString user.uid;
              GROUP_ID = toString user.gid;
              TZ = config.time.timeZone;
              DATABASE_URL = "jdbc:mariadb://grimmory-db:3306/booklore";
              FORCE_DISABLE_OIDC = "false";
              OIDC_ALLOW_UNSAFE_HOSTS = "true";
              REMOTE_AUTH_ENABLED = "false";
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
            dashboard.enable = false;
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
          dashboard = {
            name = "Audiobookshelf";
          };
          type = "proxy";
          # Use the application's login so native streaming clients can authenticate.
          auth = null;
          path = "/audiobookshelf";
          host = "audiobookshelf";
          port = 8000;
        };

        media.endpoints.grimmory = {
          dashboard = {
            name = "Grimmory";
            iconUrl = "https://raw.githubusercontent.com/grimmory-tools/grimmory/develop/assets/logo.svg";
          };
          type = "proxy";
          # Native OIDC and application tokens also work for API/mobile clients.
          auth = null;
          path = "/grimmory";
          host = "grimmory";
          port = 6060;
        };
      };
    };
  };
}
