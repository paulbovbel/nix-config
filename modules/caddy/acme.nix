{
  config,
  lib,
  ...
}: let
  cfg = config.caddy;
  domain = config.networking.domain;
  publicHosts = lib.unique (lib.concatMap (site: map (entry: entry.host) (lib.filter (entry: entry.tls == "public") site.domains)) (lib.attrValues cfg.sites));
  coveredByWildcard = host:
    lib.hasSuffix ".${domain}" host
    && !lib.hasInfix "." (lib.removeSuffix ".${domain}" host);
in {
  config = lib.mkIf cfg.enable {
    age.secrets.aws-access-env.file = ../../secrets/server/aws-access-env.age;

    rootFs.persistDirectories = ["/var/lib/acme"];

    security.acme = {
      acceptTerms = true;
      certs.caddy = {
        inherit domain;
        inherit (cfg) email;
        extraDomainNames = ["*.${domain}"] ++ lib.filter (host: host != domain && !coveredByWildcard host) publicHosts;
        dnsProvider = "route53";
        environmentFile = config.age.secrets.aws-access-env.path;
        reloadServices = ["caddy.service"];
      };
    };

    systemd.services.acme-order-renew-caddy = {
      # Start issuance on activation as well as through the renewal timer.
      wantedBy = ["multi-user.target"];
      restartTriggers = [config.age.secrets.aws-access-env.file];
    };
  };
}
