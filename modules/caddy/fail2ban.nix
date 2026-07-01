{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.caddy.enable {
    services.fail2ban = {
      enable = true;
      daemonSettings.Definition.logtarget = "SYSOUT";
      jails.caddy-basic-auth = {
        filter = ''
          [Definition]
          failregex = ^.*"remote_ip": "<HOST>".*"Authorization": \["REDACTED"\].*"status": 401.*$
          ignoreregex =
        '';
        settings = {
          enabled = true;
          chain = "INPUT";
          port = "http,https";
          backend = "systemd";
          journalmatch = "_SYSTEMD_UNIT=caddy.service";
        };
      };

      jails.caddy-auth-portal = {
        filter = ''
          [Definition]
          failregex = ^.*"remote_ip": "<HOST>".*"uri": "/auth/.*".*"status": (401|403).*$
          ignoreregex =
        '';
        settings = {
          enabled = true;
          chain = "INPUT";
          port = "http,https";
          backend = "systemd";
          journalmatch = "_SYSTEMD_UNIT=caddy.service";
        };
      };
    };
  };
}
