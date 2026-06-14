{
  config,
  lib,
  pkgs,
  ...
}: let
  datasets = config.storage.datasets;
  tailscaleSocket = "/run/tailscale/tailscaled.sock";
  caddyImageName = "localhost/caddy-proxy";
  caddyPlugins = {
    security = {
      module = "github.com/greenpau/caddy-security";
      version = "v1.1.62";
    };
    route53 = {
      module = "github.com/caddy-dns/route53";
      version = "v1.6.2";
    };
  };
  customCaddy = pkgs.caddy.withPlugins {
    plugins = lib.mapAttrsToList (_: plugin: "${plugin.module}@${plugin.version}") caddyPlugins;
    hash = lib.fakeHash;
  };
  caddyImageTag = customCaddy.version;
  caddyImage = pkgs.dockerTools.buildLayeredImage {
    name = caddyImageName;
    tag = caddyImageTag;
    contents = [
      customCaddy
      pkgs.cacert
      pkgs.tzdata
    ];
    config = {
      Entrypoint = ["${customCaddy}/bin/caddy"];
      Cmd = ["run" "--config" "/etc/caddy/Caddyfile" "--adapter" "caddyfile"];
    };
  };
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
        image = "${caddyImageName}:${caddyImageTag}";
        ports = ["80:80" "443:443"];
        volumes = [
          "/etc/caddy/Caddyfile:/etc/caddy/Caddyfile:ro"
          "${datasets.app.children.caddy.path}/data:/data"
          "${datasets.app.children.caddy.path}/config:/config"
          "${tailscaleSocket}:${tailscaleSocket}"
        ];
        environment.TZ = config.time.timeZone;
        secretEnvironmentFiles = [
          config.age.secrets.google-oauth-env.path
          config.age.secrets.aws-access-env.path
          config.age.secrets.web-credentials-env.path
        ];
        derivedEnvironmentFiles = ["caddy-token-secret" "caddy-basic-auth"];
        unitRequires = ["caddy-proxy-image.service"];
        unitAfter = ["caddy-proxy-image.service"];
        requiresMountsFor = ["/storage"];
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
        caddy-render = {
          description = "Render containerized Caddy configuration";
          wantedBy = ["multi-user.target"];
          wants = ["network-online.target"];
          after = ["network-online.target"];
          before = ["caddy.service"];
          path = [pkgs.coreutils];
          serviceConfig.Type = "oneshot";
          script = ''
            set -euo pipefail
            install -d -m 0755 /etc/caddy
            install -m 0644 ${config.caddy.caddyfile} /etc/caddy/Caddyfile
          '';
        };

        caddy = {
          requires = ["caddy-render.service" "caddy-proxy-image.service"];
          after = ["caddy-render.service" "caddy-proxy-image.service"];
        };
      };
    };

    environment.etc."containers/systemd/caddy-proxy.image".text = ''
      [Image]
      Image=oci-archive:${caddyImage}
      ImageTag=${caddyImageName}:${caddyImageTag}
    '';

    networking.firewall.allowedTCPPorts = [80 443];
  };
}
