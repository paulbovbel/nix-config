{
  config,
  lib,
  ...
}: let
  cfg = config.mediaServer;
  datasets = config.storage.datasets;
  inherit (config.podmanServer) user;
in {
  config = lib.mkIf (cfg.enable && cfg.components.library.enable) {
    age.secrets.web-credentials-env.file = ../../../secrets/server/web-credentials-env.age;

    storage.datasets.app.children = {
      grimmory = {};
      grimmory-db = {};
    };

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
        grimmory-db = {
          image = "lscr.io/linuxserver/mariadb:11.4.8";
          environment = {
            MYSQL_DATABASE = "booklore";
            TZ = config.time.timeZone;
          };
          derivedEnvironmentFiles = ["grimmory-db"];
          volumes = ["${datasets.app.children."grimmory-db".path}:/config"];
          requiresMountsFor = ["/storage"];
        };

        grimmory = {
          image = "ghcr.io/paulbovbel/grimmory:preview-7815e6d";
          dependsOn = ["grimmory-db"];
          environment = {
            USER_ID = user.uid;
            GROUP_ID = user.gid;
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
          derivedEnvironmentFiles = ["grimmory"];
          volumes = [
            "${datasets.app.children.grimmory.path}:/app/data"
            "${datasets.media.children.books.path}:/books"
            "${datasets.downloads.path}/bookdrop:/bookdrop"
          ];
          requiresMountsFor = ["/storage"];
        };
      };
    };

    caddy.endpoints = {
      grimmory-kobo = {
        type = "proxy";
        auth = null;
        path = "/grimmory/api/kobo";
        host = "grimmory";
        port = 6060;
      };

      grimmory = {
        type = "proxy";
        auth = "oauth";
        path = "/grimmory";
        host = "grimmory";
        port = 6060;
        role = "admin";
      };
    };
  };
}
