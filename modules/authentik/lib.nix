{lib}: rec {
  upstream = "http://authentik:9000";
  # Identity is used only for Caddy authorization; preserve protocol headers such as CSRF.
  identityHeaders = [
    "X-Authentik-Username"
    "X-Authentik-Groups"
    "X-Authentik-Email"
    "X-Authentik-Name"
    "X-Authentik-Uid"
  ];
  siteHasForwardAuth = site: lib.any (endpoint: endpoint.auth == "oauth") (lib.attrValues site.endpoints);
  domainAddress = domain: domain.host + lib.optionalString (domain.listenPort != null) ":${toString domain.listenPort}";
  protectedDomains = sites:
    lib.unique (lib.concatMap (site:
      if siteHasForwardAuth site
      then map domainAddress site.domains
      else []) (lib.attrValues sites));
  clientSecretEnvironment = application: "AUTHENTIK_${lib.toUpper (lib.replaceStrings ["-"] ["_"] application.clientId)}_CLIENT_SECRET";
}
