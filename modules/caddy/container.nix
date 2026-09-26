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
  caddyPlugins = [
    "github.com/greenpau/caddy-security@v1.2.2"
    "github.com/caddy-dns/route53@v1.6.2"
  ];
  caddyPackage = pkgs.caddy.withPlugins {
    plugins = caddyPlugins;
    hash = "sha256-cofEVMOovDDIzo3VoVktTK8C2+uYKLvnslTPkUua6Jc=";
  };
  caddyImageTag = builtins.hashString "sha256" (builtins.toJSON caddyPlugins);
  caddyImage = pkgs.dockerTools.buildLayeredImage {
    name = "localhost/caddy";
    tag = caddyImageTag;
    contents = [caddyPackage pkgs.tzdata pkgs.dockerTools.caCertificates];
    config = {
      Cmd = ["caddy" "run" "--config" "/etc/caddy/Caddyfile" "--adapter" "caddyfile"];
      Env = [
        "PATH=${caddyPackage}/bin"
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
      google-oauth-env.file = ../../secrets/server/google-oauth-env.age;
      aws-access-env.file = ../../secrets/server/aws-access-env.age;
      web-credentials-env.file = ../../secrets/server/web-credentials-env.age;
    };

    storage.datasets.app.children.caddy = {};

    podmanServer = {
      containers.caddy = {
        quadlet.containerConfig = {
          image = caddyImageRef;
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
          after = ["network-online.target"] ++ caddyEnvUnits;
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
              ${lib.escapeShellArg caddyImageRef} \
              caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

            install -m 0644 "$candidate" ${lib.escapeShellArg caddyfilePath}
          '';
        };
      };
    };
  };
}
