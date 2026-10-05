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
  caddyfilePath = "${datasets.app.children.caddy.path}/Caddyfile";
  certificateDirectory = config.security.acme.certs.caddy.directory;
  certificateVolume = "${certificateDirectory}:/certs:ro";
  caddyEnvFiles = [
    config.age.secrets.web-credentials-env.path
    config.podmanServer.derivedEnvFiles.caddy-basic-auth.path
  ];
  caddyEnvFileArgs = lib.escapeShellArgs (lib.concatMap (file: ["--env-file" file]) caddyEnvFiles);
  caddyEnvUnits = [
    "podman-server-caddy-basic-auth-env.service"
  ];
  caddyImage = pkgs.dockerTools.buildLayeredImage {
    name = "localhost/caddy";
    contents = [pkgs.caddy pkgs.tzdata pkgs.dockerTools.caCertificates];
    config = {
      Cmd = ["caddy" "run" "--config" "/etc/caddy/Caddyfile" "--adapter" "caddyfile"];
      Env = [
        "PATH=${pkgs.caddy}/bin"
        "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
        "XDG_CONFIG_HOME=/config"
        "XDG_DATA_HOME=/data"
        "ZONEINFO=${pkgs.tzdata}/share/zoneinfo"
      ];
    };
  };
  caddyImageRef = "docker-archive:${caddyImage}";
in {
  config = lib.mkIf cfg.enable {
    age.secrets = {
      web-credentials-env.file = ../../secrets/server/web-credentials-env.age;
    };

    storage.datasets.app.children.caddy = {};

    podmanServer = {
      containers.caddy = {
        ports = map (port: {
          hostPort = port;
          exposure = ["wan" "tailnet"];
        }) (lib.unique ([80 443] ++ domainListenPorts));
        quadlet.containerConfig = {
          image = caddyImageRef;
          volumes = [
            certificateVolume
            "${caddyfilePath}:/etc/caddy/Caddyfile:ro"
            "${datasets.app.children.caddy.path}/data:/data"
            "${datasets.app.children.caddy.path}/config:/config"
            "${tailscaleSocket}:${tailscaleSocket}"
          ];
          environments = {
            TZ = config.time.timeZone;
          };
        };
        secretEnvironmentFiles = [config.age.secrets.web-credentials-env.path];
        derivedEnvironmentFiles = ["caddy-basic-auth"];
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
      };
    };

    systemd = {
      tmpfiles.rules = [
        "d /etc/caddy 0755 root root - -"
      ];

      services = {
        caddy = {
          restartTriggers = [
            config.caddy.caddyfile
            config.age.secrets.web-credentials-env.file
          ];
          # --force reloads certificates even when the Caddyfile has not changed.
          serviceConfig.ExecReload = "${pkgs.podman}/bin/podman exec caddy caddy reload --force --config /etc/caddy/Caddyfile --adapter caddyfile";
        };

        caddy-render = {
          description = "Validate and install rendered Caddyfile";
          wants = ["network-online.target"] ++ caddyEnvUnits;
          requires = ["acme-caddy.service"];
          before = ["caddy.service"];
          after = ["network-online.target" "acme-caddy.service"] ++ caddyEnvUnits;
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

            ${pkgs.podman}/bin/podman run --rm --pull=never --network host \
              ${caddyEnvFileArgs} \
              --volume "$candidate:/etc/caddy/Caddyfile:ro" \
              --volume ${lib.escapeShellArg certificateVolume} \
              ${lib.escapeShellArg caddyImageRef} \
              caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

            install -m 0644 "$candidate" ${lib.escapeShellArg caddyfilePath}
          '';
        };
      };
    };
  };
}
