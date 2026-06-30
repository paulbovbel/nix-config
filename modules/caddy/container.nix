{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.caddy;
  datasets = config.storage.datasets;
  tailscaleSocket = "/run/tailscale/tailscaled.sock";
  domainListenPorts = lib.unique (lib.filter (port: port != null) (lib.concatMap (site: map (domain: domain.listenPort) site.domains) (lib.attrValues cfg.sites)));
  domainPublishPorts = map (port: "${toString port}:${toString port}") domainListenPorts;
  caddyEnvFiles = [
    config.age.secrets.google-oauth-env.path
    config.age.secrets.aws-access-env.path
    config.age.secrets.web-credentials-env.path
    config.podmanServer.derivedEnvFiles.caddy-token-secret.path
    config.podmanServer.derivedEnvFiles.caddy-basic-auth.path
  ];
  caddyEnvFileArgs = lib.escapeShellArgs (lib.concatMap (file: ["--env-file" file]) caddyEnvFiles);
  caddyEnvUnits = [
    "podman-server-caddy-token-secret-env.service"
    "podman-server-caddy-basic-auth-env.service"
  ];
  caddyImage = "localhost/caddy";
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
  config = lib.mkIf cfg.enable {
    age.secrets = {
      google-oauth-env.file = ../../secrets/server/google-oauth-env.age;
      aws-access-env.file = ../../secrets/server/aws-access-env.age;
      web-credentials-env.file = ../../secrets/server/web-credentials-env.age;
    };

    storage.datasets.app.children.caddy = {};

    podmanServer = {
      containers.caddy = {
        build.buildConfig = {
          file = caddyContainerfile.outPath;
          tag = caddyImage;
        };
        quadlet.containerConfig = {
          publishPorts = ["80:80" "443:443"] ++ domainPublishPorts;
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
        secretEnvironmentFiles = lib.take 3 caddyEnvFiles;
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
          description = "Install rendered Caddyfile and reload containerized Caddy";
          wantedBy = ["multi-user.target"];
          wants = ["network-online.target" "caddy-build.service"] ++ caddyEnvUnits;
          after = ["network-online.target" "caddy-build.service"] ++ caddyEnvUnits;
          before = ["caddy.service"];
          path = [pkgs.coreutils];
          restartTriggers = [config.caddy.caddyfile];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            RuntimeDirectory = "caddy-render";
          };
          script = ''
            set -euo pipefail

            candidate="$RUNTIME_DIRECTORY/Caddyfile"
            install -d -m 0755 /etc/caddy
            install -m 0644 ${config.caddy.caddyfile} "$candidate"

            ${pkgs.podman}/bin/podman run --rm --pull=never --network host \
              ${caddyEnvFileArgs} \
              --volume "$candidate:/etc/caddy/Caddyfile:ro" \
              ${caddyImage} \
              caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

            install -m 0644 "$candidate" /etc/caddy/Caddyfile
            if [ "$(${pkgs.podman}/bin/podman inspect -f '{{.State.Running}}' caddy 2>/dev/null || true)" = true ]; then
              ${pkgs.podman}/bin/podman exec caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
            fi
          '';
        };
      };
    };
  };
}
