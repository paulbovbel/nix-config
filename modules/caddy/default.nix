{
  config.moduleDocumentation.caddy = {
    title = "Caddy";
    category = "Networking and access";
    summary = "Declarative domains, authenticated routes, reverse proxies, and static shares.";
  };

  imports = [
    ./options.nix
    ./caddyfile.nix
    ./acme.nix
    ./container.nix
    ./fail2ban.nix
    ./share.nix
  ];
}
