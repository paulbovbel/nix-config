{
  config,
  containerImages,
  jellyfin-plugin-sso,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mediaServer;
  datasets = config.storage.datasets;
  inherit (config.podmanServer) user;
  sso = jellyfin-plugin-sso.packages.${pkgs.stdenv.hostPlatform.system}.default;
  baseUrl = "https://${config.networking.hostName}.${config.networking.domain}";
in {
  config = lib.mkIf cfg.library.enable {
    storage.datasets.app.children.jellyfin = {};

    systemd.tmpfiles.rules = map (path: "d ${datasets.app.children.jellyfin.path}/${path} 0755 ${user.name} ${user.group} - -") [
      "data"
      "data/plugins"
      "data/plugins/SSO-Auth"
    ];

    authentik.applications.jellyfin = {
      name = "Jellyfin";
      launchUrl = "${baseUrl}/jellyfin/sso/OID/start/authentik";
      iconUrl = config.caddy.sites.media.endpoints.jellyfin.dashboard.iconUrl;
      redirectUris = ["${baseUrl}/jellyfin/sso/OID/redirect/authentik"];
      scopes = ["openid" "email" "profile" "groups"];
      includeClaimsInIdToken = true;
    };

    podmanServer.containers.jellyfin.quadlet = {
      containerConfig = {
        image = containerImages.jellyfin;
        environments = {
          PUID = toString user.uid;
          PGID = toString user.gid;
          TZ = config.time.timeZone;
        };
        volumes =
          [
            "${datasets.app.children.jellyfin.path}:/config"
            "${datasets.media.path}:/data:ro"
          ]
          ++ map (file: "${sso}/${file}:/config/data/plugins/SSO-Auth/${file}:ro") sso.pluginFiles;
        devices = ["/dev/dri:/dev/dri"];
      };
    };

    caddy.sites.media.endpoints.jellyfin = {
      dashboard = {
        enable = false;
        name = "Jellyfin";
      };
      type = "proxy";
      auth = null;
      path = "/jellyfin";
      host = "jellyfin";
      port = 8096;
    };
  };
}
