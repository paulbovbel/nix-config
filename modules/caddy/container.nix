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
  caddyfilePath = "${datasets.app.children.caddy.path}/Caddyfile";
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
  caddyVersion = "2.9.1";
  caddyPlugins = [
    "github.com/greenpau/caddy-security@v1.1.29"
    "github.com/caddy-dns/route53@v1.5.1"
  ];
  caddyContainerfileText = ''
    FROM caddy:${caddyVersion}-builder AS builder

    RUN xcaddy build ${lib.concatMapStringsSep " " (plugin: "\\\n      --with ${plugin}") caddyPlugins}

    FROM caddy:${caddyVersion}

    COPY --from=builder /usr/bin/caddy /usr/bin/caddy

    # see https://github.com/caddyserver/caddy-docker/issues/58
    RUN apk add --no-cache tzdata
  '';
  caddyImage = "localhost/caddy:${builtins.hashString "sha256" caddyContainerfileText}";
  caddyContainerfile = pkgs.writeText "Containerfile" caddyContainerfileText;
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
        build.autoStart = false;
        quadlet.containerConfig = {
          publishPorts = ["80:80" "443:443"] ++ domainPublishPorts;
          volumes = [
            "${caddyfilePath}:/etc/caddy/Caddyfile:ro"
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
          ConditionPathExists = [caddyfilePath];
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
        caddy.restartTriggers = [
          config.caddy.caddyfile
          config.age.secrets.google-oauth-env.file
          config.age.secrets.aws-access-env.file
          config.age.secrets.web-credentials-env.file
        ];

        caddy-render = {
          description = "Validate and install rendered Caddyfile";
          wants = ["network-online.target"] ++ caddyEnvUnits;
          before = ["caddy.service"];
          after = ["network-online.target"] ++ caddyEnvUnits ++ ["caddy-build.service"];
          path = [pkgs.coreutils];
          serviceConfig = {
            Type = "oneshot";
            RuntimeDirectory = "caddy-render";
          };
          script = ''
            set -euo pipefail

            candidate="$RUNTIME_DIRECTORY/Caddyfile"
            install -d -m 0755 /etc/caddy
            install -d -m 0755 ${lib.escapeShellArg datasets.app.children.caddy.path}
            install -m 0644 ${config.caddy.caddyfile} "$candidate"

            if ! ${pkgs.podman}/bin/podman image exists ${lib.escapeShellArg caddyImage}; then
              ${pkgs.systemd}/bin/systemctl start caddy-build.service
            fi

            ${pkgs.podman}/bin/podman run --rm --pull=never --network host \
              ${caddyEnvFileArgs} \
              --volume "$candidate:/etc/caddy/Caddyfile:ro" \
              ${lib.escapeShellArg caddyImage} \
              caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

            install -m 0644 "$candidate" ${lib.escapeShellArg caddyfilePath}
          '';
        };
      };
    };
  };
}
