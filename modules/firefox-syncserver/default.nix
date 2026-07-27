{
  config,
  lib,
  ...
}: let
  cfg = config.firefoxSyncServer;
  datasets = config.storage.datasets;
  domain = "${cfg.subdomain}.${config.networking.domain}";
  databaseUrl = "postgres://$POSTGRES_USER:$POSTGRES_PASSWORD@firefox-syncserver-postgres:5432/$POSTGRES_DB";
in {
  imports = [./options.nix];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.storage.enable;
        message = "firefoxSyncServer.enable requires storage.enable for database storage.";
      }
      {
        assertion = config.caddy.enable;
        message = "firefoxSyncServer.enable requires caddy.enable for public HTTPS exposure.";
      }
    ];

    storage.datasets.app.children.firefox-syncserver = {};

    age.secrets.firefox-syncserver-env.file = ../../secrets/server/firefox-syncserver-env.age;

    podmanServer = {
      derivedEnvFiles.firefox-syncserver = {
        secretEnvironmentFiles = [config.age.secrets.firefox-syncserver-env.path];
        variables = {
          POSTGRES_DB = "$POSTGRES_DB";
          POSTGRES_PASSWORD = "$POSTGRES_PASSWORD";
          POSTGRES_USER = "$POSTGRES_USER";
          SYNC_MASTER_SECRET = "$SYNC_MASTER_SECRET";
          SYNC_SYNCSTORAGE__DATABASE_URL = databaseUrl;
          SYNC_TOKENSERVER__DATABASE_URL = databaseUrl;
          SYNC_TOKENSERVER__FXA_METRICS_HASH_SECRET = "$SYNC_TOKENSERVER__FXA_METRICS_HASH_SECRET";
        };
      };

      containers = {
        firefox-syncserver-postgres = {
          quadlet.serviceConfig = {
            Restart = "always";
            RestartSec = 10;
          };
          quadlet.containerConfig = {
            image = "docker.io/library/postgres:18";
            volumes = [
              "${datasets.app.children.firefox-syncserver.path}/postgres:/var/lib/postgresql"
            ];
          };
          derivedEnvironmentFiles = ["firefox-syncserver"];
        };

        firefox-syncserver = {
          dependsOn = ["firefox-syncserver-postgres"];
          quadlet.serviceConfig = {
            Restart = "always";
            RestartSec = 10;
          };
          quadlet.containerConfig = {
            image = "ghcr.io/mozilla-services/syncstorage-rs/syncserver-postgres:de108fda99";
            environments = {
              RUST_LOG = "info";
              SYNC_HOST = "0.0.0.0";
              SYNC_HUMAN_LOGS = "false";
              SYNC_PORT = toString cfg.port;
              SYNC_TOKENSERVER__ENABLED = "true";
              SYNC_TOKENSERVER__FXA_EMAIL_DOMAIN = "api.accounts.firefox.com";
              SYNC_TOKENSERVER__FXA_OAUTH_SERVER_URL = "https://oauth.accounts.firefox.com";
              SYNC_TOKENSERVER__INIT_NODE_URL = "https://${domain}";
              SYNC_TOKENSERVER__NODE_TYPE = "postgres";
              SYNC_TOKENSERVER__RUN_MIGRATIONS = "true";
            };
            podmanArgs = ["--platform=linux/amd64"];
          };
          derivedEnvironmentFiles = ["firefox-syncserver"];
        };
      };
    };

    caddy.sites.firefox-syncserver = {
      domains = [
        {
          host = domain;
        }
      ];
      endpoints.syncserver = {
        type = "proxy";
        auth = null;
        path = "/";
        host = "firefox-syncserver";
        inherit (cfg) port;
      };
    };
  };
}
