{
  config,
  lib,
  pkgs,
  ...
}: let
  datasets = config.storage.datasets;
  tailscaleSocket = "/run/tailscale/tailscaled.sock";
  caddyVersion = "2.9.1";
  caddyPlugins = [
    "github.com/greenpau/caddy-security@v1.1.29"
    "github.com/caddy-dns/route53@v1.5.1"
  ];
  caddyContainerfile = pkgs.writeText "Containerfile" ''
    FROM caddy:${caddyVersion}-builder AS builder

    RUN xcaddy build ${lib.concatMapStringsSep " " (plugin: "\\\n      --with ${plugin}") caddyPlugins}

    FROM caddy:${caddyVersion}

    COPY --from=builder /usr/bin/caddy /usr/bin/caddy

    # see https://github.com/caddyserver/caddy-docker/issues/58
    RUN apk add --no-cache tzdata
  '';
in {
  config = lib.mkIf config.caddy.enable {
    age.secrets = {
      google-oauth-env.file = ../../secrets/server/google-oauth-env.age;
      aws-access-env.file = ../../secrets/server/aws-access-env.age;
      web-credentials-env.file = ../../secrets/server/web-credentials-env.age;
    };

    storage.datasets.app.children.caddy = {};

    podmanServer = {
      containers.caddy = {
        build.buildConfig.file = caddyContainerfile.outPath;
        quadlet.containerConfig = {
          publishPorts = ["80:80" "443:443"];
          volumes = [
            "/etc/caddy/Caddyfile:/etc/caddy/Caddyfile:ro"
            "${datasets.app.children.caddy.path}/data:/data"
            "${datasets.app.children.caddy.path}/config:/config"
            "${tailscaleSocket}:${tailscaleSocket}"
          ];
          environments = {
            TZ = config.time.timeZone;
          };
        };
        secretEnvironmentFiles = [
          config.age.secrets.google-oauth-env.path
          config.age.secrets.aws-access-env.path
          config.age.secrets.web-credentials-env.path
        ];
        derivedEnvironmentFiles = ["caddy-token-secret" "caddy-basic-auth"];
        quadlet.unitConfig = {
          Requires = ["caddy-render.service"];
          After = ["caddy-render.service"];
        };
      };

      derivedEnvFiles = {
        caddy-basic-auth = {
          secretEnvironmentFiles = [config.age.secrets.web-credentials-env.path];
          packages = [pkgs.caddy];
          variables = {
            BASIC_AUTH_HASH = ''$(caddy hash-password --plaintext "$WEB_PASSWORD")'';
            BASIC_AUTH_HEADER = ''$(printf '%s:%s' "$WEB_USER" "$WEB_PASSWORD" | base64 -w0)'';
          };
        };

        caddy-token-secret = {
          packages = [pkgs.util-linux];
          createIfMissing = true;
          directoryMode = "0700";
          variables.CADDY_TOKEN_SECRET = ''$(uuidgen)'';
        };
      };
    };

    systemd = {
      tmpfiles.rules = [
        "d /etc/caddy 0755 root root - -"
      ];

      services = {
        caddy.restartTriggers = [config.caddy.caddyfile];

        caddy-render = {
          description = "Render containerized Caddy configuration";
          wantedBy = ["multi-user.target"];
          wants = ["network-online.target"];
          after = ["network-online.target"];
          before = ["caddy.service"];
          path = [pkgs.coreutils];
          serviceConfig = {
            Type = "oneshot";
          };
          script = ''
            set -euo pipefail
            install -d -m 0755 /etc/caddy
            install -m 0644 ${config.caddy.caddyfile} /etc/caddy/Caddyfile
            ${pkgs.podman}/bin/podman exec caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile || true
          '';
        };
      };
    };
  };
}
