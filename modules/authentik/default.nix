{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.authentik;
  state = config.storage.datasets.app.children.authentik.path;
  database = config.storage.datasets.app.children.authentik-db.path;
  applications = lib.attrValues cfg.applications;
  confidentialApplications = lib.filter (application: application.clientType == "confidential") applications;
  generatedSecretApplications = lib.filter (application: application.generateClientSecret) confidentialApplications;
  inherit (import ./lib.nix {inherit lib;}) clientSecretEnvironment;
  generatedSecrets = builtins.listToAttrs (map (application: lib.nameValuePair (clientSecretEnvironment application) "$(openssl rand -hex 32)") generatedSecretApplications);
  propagatedSecrets = builtins.mapAttrs (name: _: "$" + name) generatedSecrets;
  declaredUsers = map (user: user.email) cfg.users;
  inherit (config.podmanServer) user;
  mkContainer = command: {
    dependsOn = ["authentik-db"];
    derivedEnvironmentFiles = ["authentik"];
    secretEnvironmentFiles = [config.age.secrets.google-oauth-env.path];
    quadlet = {
      containerConfig = {
        inherit (cfg) image;
        exec = command;
        autoUpdate = lib.mkForce null;
        environments = {
          AUTHENTIK_POSTGRESQL__HOST = "authentik-db";
          AUTHENTIK_POSTGRESQL__NAME = "authentik";
          AUTHENTIK_POSTGRESQL__USER = "authentik";
          AUTHENTIK_ERROR_REPORTING__ENABLED = "false";
          AUTHENTIK_DISABLE_UPDATE_CHECK = "true";
        };
        volumes = [
          "${state}/data:/data"
          "${cfg.blueprint}:/blueprints/custom/nix-config.yaml:ro"
        ];
        podmanArgs = ["--shm-size=512m"] ++ lib.optional (command == "worker") "--user=0:0";
      };
      serviceConfig.RestartSec = "10s";
    };
  };
in {
  imports = [./options.nix ./blueprint.nix];
  options.moduleDocumentation.authentik = lib.mkOption {
    internal = true;
    readOnly = true;
    default = {
      title = "Authentik";
      summary = "Google-backed identity, Caddy forward authentication, and application OIDC.";
    };
  };
  config = lib.mkIf cfg.enable {
    assertions =
      [
        {
          assertion = config.caddy.enable;
          message = "Authentik requires Caddy ingress.";
        }
        {
          assertion = lib.all (email: lib.elem email declaredUsers) cfg.adminUsers;
          message = "authentik.adminUsers must only contain emails declared in authentik.users.";
        }
        {
          assertion = lib.all (role: builtins.match "[a-zA-Z0-9_-]+" role != null) cfg.roles;
          message = "Authentik role names must contain only letters, digits, underscores, or hyphens.";
        }
        {
          assertion = lib.all (role: lib.elem role cfg.roles) (lib.concatMap (user: user.roles) cfg.users);
          message = "Authentik user roles must be declared in authentik.roles.";
        }
      ]
      ++ lib.concatMap (name: let
        application = cfg.applications.${name};
      in [
        {
          assertion = application.redirectUris != [];
          message = "authentik.applications.${name}.redirectUris must not be empty.";
        }
        {
          assertion = lib.all (lib.hasPrefix "https://") application.redirectUris;
          message = "authentik.applications.${name}.redirectUris must only contain HTTPS URLs.";
        }
        {
          assertion = application.clientType == "confidential" || !application.generateClientSecret;
          message = "authentik.applications.${name}.generateClientSecret requires a confidential client.";
        }
        {
          assertion = !lib.elem "groups" application.scopes || application.includeClaimsInIdToken;
          message = "authentik.applications.${name} must include claims in the ID token when requesting the groups scope.";
        }
      ]) (lib.attrNames cfg.applications);
    age.secrets.google-oauth-env.file = ../../secrets/server/google-oauth-env.age;
    storage.datasets.app.children = {
      authentik = {};
      authentik-db = {};
    };
    systemd.tmpfiles.rules = ["d ${state}/data 0750 1000 1000 - -"];
    podmanServer = {
      paths.authentik = state;
      derivedEnvFiles = {
        authentik-secrets = {
          path = "${state}/secrets/runtime.env";
          createIfMissing = true;
          directoryMode = "0700";
          packages = [pkgs.openssl];
          after = ["zfs-mount.service"];
          variables =
            {
              AUTHENTIK_SECRET_KEY = "$(openssl rand -hex 60)";
              POSTGRES_PASSWORD = "$(openssl rand -hex 36)";
              AUTHENTIK_BOOTSTRAP_PASSWORD = "$(openssl rand -hex 32)";
            }
            // generatedSecrets;
        };
        authentik = {
          derivedEnvironmentFiles = ["authentik-secrets"];
          variables =
            {
              AUTHENTIK_SECRET_KEY = "$AUTHENTIK_SECRET_KEY";
              AUTHENTIK_POSTGRESQL__PASSWORD = "$POSTGRES_PASSWORD";
              AUTHENTIK_BOOTSTRAP_PASSWORD = "$AUTHENTIK_BOOTSTRAP_PASSWORD";
            }
            // propagatedSecrets;
        };
        authentik-db = {
          derivedEnvironmentFiles = ["authentik-secrets"];
          variables.POSTGRES_PASSWORD = "$POSTGRES_PASSWORD";
        };
      };
      containers = {
        authentik = mkContainer "server";
        authentik-worker = mkContainer "worker";
        authentik-db = {
          derivedEnvironmentFiles = ["authentik-db"];
          quadlet.containerConfig = {
            image = "docker.io/library/postgres:16-alpine";
            autoUpdate = lib.mkForce null;
            podmanArgs = ["--user=${toString user.uid}:${toString user.gid}"];
            environments = {
              POSTGRES_DB = "authentik";
              POSTGRES_USER = "authentik";
            };
            volumes = ["${database}:/var/lib/postgresql/data"];
          };
          quadlet.serviceConfig.RestartSec = "10s";
        };
      };
    };
    caddy.sites.authentik = {
      domains = [{host = cfg.domain;}];
      endpoints.authentik = {
        type = "proxy";
        auth = null;
        path = "/";
        host = "authentik";
        port = 9000;
      };
    };
  };
}
