{
  lib,
  pkgs,
  ...
}: let
  googleEnv = pkgs.writeText "test-google.env" ''
    GOOGLE_OAUTH2_CLIENT_ID=test-google
    GOOGLE_OAUTH2_CLIENT_SECRET=test-google-secret
  '';
  endpoint = name: path: auth: role: {
    type = "proxy";
    host = "example";
    port = 8080;
    inherit path auth role;
    dashboard = {
      inherit name;
      iconUrl = "https://icons.example.test/application.svg";
    };
  };
in {
  imports = [
    ../../documentation/options.nix
    ../default.nix
    ../../caddy/options.nix
    ../../podman-server/options.nix
    ../../podman-server/runtime.nix
    ../../upnp
  ];

  # Stub storage and agenix inputs; this fixture needs neither disks nor real secrets.
  options = {
    storage.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    storage.datasets.app.children = lib.mkOption {
      default = {};
      type = lib.types.attrsOf (lib.types.submodule ({name, ...}: {
        options.path = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/${name}";
        };
      }));
    };
    age.secrets = lib.mkOption {
      default = {};
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          file = lib.mkOption {type = lib.types.anything;};
          path = lib.mkOption {type = lib.types.str;};
        };
      });
    };
  };

  config = {
    age.secrets.google-oauth-env = {
      file = lib.mkForce googleEnv;
      path = "/run/test-google.env";
    };
    authentik = {
      enable = true;
      domain = "auth.example.test";
      adminUsers = ["admin@example.test"];
      users = [
        {
          email = "admin@example.test";
          roles = ["admin" "user"];
        }
        {
          email = "member@example.test";
          roles = ["user"];
        }
      ];
      applications = {
        native = {
          name = "Native";
          clientType = "public";
          launchUrl = "https://apps.example.test:8443/native/";
          iconUrl = "https://icons.example.test/native.svg";
          redirectUris = ["https://apps.example.test:8443/native/callback"];
          scopes = ["openid" "email" "profile" "groups"];
          includeClaimsInIdToken = true;
        };
        confidential = {
          name = "Confidential";
          iconUrl = "https://icons.example.test/confidential.svg";
          launchUrl = "https://apps.example.test:8443/confidential/";
          redirectUris = ["https://apps.example.test:8443/confidential/callback"];
        };
        fresh = {
          name = "Fresh";
          iconUrl = "https://icons.example.test/fresh.svg";
          launchUrl = "https://apps.example.test:8443/fresh/";
          redirectUris = ["https://apps.example.test:8443/fresh/callback"];
        };
      };
    };
    caddy = {
      enable = true;
      sites.demo = {
        domains = [
          {
            host = "apps.tailnet.example.test";
            tls = "tailscale";
          }
          {
            host = "apps.example.test";
            listenPort = 8443;
          }
        ];
        endpoints = {
          native = endpoint "Native" "/native" null null;
          confidential = endpoint "Confidential" "/confidential" null null;
          fresh = endpoint "Fresh" "/fresh" null null;
          member = endpoint "Member" "/member" "oauth" "user";
          admin = endpoint "Admin" "/admin" "oauth" "admin";
          home = endpoint "Home" "/" null null;
          api = (endpoint "API" "/api" null null) // {dashboard.enable = false;};
        };
      };
    };
    podmanServer = {
      user.uid = 0;
      user.gid = 0;
      containers = {
        authentik.quadlet.containerConfig = {
          environments = {
            AUTHENTIK_LOG_LEVEL = "warning";
            REQUESTS_CA_BUNDLE = "/tests/google.crt";
          };
          volumes = ["/var/lib/test-google/google.crt:/tests/google.crt:ro"];
          podmanArgs = ["--add-host=accounts.google.com:host-gateway"];
        };
        authentik-worker.quadlet.containerConfig = {
          environments = {
            AUTHENTIK_LOG_LEVEL = "warning";
            REQUESTS_CA_BUNDLE = "/tests/google.crt";
          };
          volumes = ["/var/lib/test-google/google.crt:/tests/google.crt:ro"];
          podmanArgs = ["--add-host=accounts.google.com:host-gateway"];
        };
      };
      derivedEnvFiles = {
        test-source.variables.TEST_ENV_REVISION = "initial";
        authentik = {
          derivedEnvironmentFiles = ["test-source"];
          variables.TEST_ENV_REVISION = "$TEST_ENV_REVISION";
        };
      };
    };
    systemd = {
      tmpfiles.rules = ["d /var/lib/authentik-db 0700 - - -"];
      services = {
        test-secret-state = {
          path = [pkgs.openssl];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            install -d -m 0755 /var/lib/test-google
            openssl req -x509 -newkey rsa:2048 -noenc -days 1 \
              -subj /CN=accounts.google.com \
              -addext subjectAltName=DNS:accounts.google.com \
              -keyout /var/lib/test-google/google.key \
              -out /var/lib/test-google/google.crt
            install -m 0600 ${googleEnv} /run/test-google.env
            install -d -m 0700 /var/lib/authentik/secrets
            install -m 0600 ${pkgs.writeText "existing-runtime.env" ''
              AUTHENTIK_SECRET_KEY=authentik-test-only-persistent-signing-key-for-minimal-vm-regression
              POSTGRES_PASSWORD=test-database-password
              AUTHENTIK_BOOTSTRAP_PASSWORD=test-bootstrap-password
              CONFIDENTIAL_CLIENT_SECRET=test-existing-client-secret
            ''} /var/lib/authentik/secrets/runtime.env
          '';
        };
        podman-server-authentik-secrets-env = {
          requires = ["test-secret-state.service"];
          after = ["test-secret-state.service"];
        };
        test-google = {
          requires = ["test-secret-state.service"];
          after = ["test-secret-state.service"];
          serviceConfig.ExecStart = "${pkgs.python3}/bin/python ${./google-discovery.py} /var/lib/test-google/google.crt /var/lib/test-google/google.key";
        };
        authentik = {
          requires = ["test-google.service"];
          after = ["test-google.service"];
        };
        authentik-worker = {
          requires = ["test-google.service"];
          after = ["test-google.service"];
        };
      };
    };
    specialisation.changed.configuration.podmanServer.derivedEnvFiles.test-source.variables.TEST_ENV_REVISION = lib.mkForce "updated";
    environment.systemPackages = [pkgs.podman];
    networking.firewall.allowedTCPPorts = [443];
    system.stateVersion = "26.05";
  };
}
