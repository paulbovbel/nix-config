{lib, ...}: {
  options.moduleDocumentation.caddy = lib.mkOption {
    internal = true;
    readOnly = true;
    default = {
      title = "Caddy";
      summary = "Declarative domains, authenticated routes, reverse proxies, and static shares.";
    };
  };

  imports = [
    ./options.nix
    ./caddyfile.nix
    ./container.nix
    ./fail2ban.nix
    ./share.nix
  ];
}
