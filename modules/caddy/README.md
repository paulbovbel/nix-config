# Caddy

The Caddy module renders declarative sites and endpoints for public or Tailscale ingress. Service-owning modules should declare their routes; host configurations generally enable Caddy, define users and roles, and set host-specific site behavior.

`options.nix` is the authoritative option reference.

## Endpoints

Declare endpoints under a logical site:

```nix
caddy.sites.media.endpoints.example = {
  type = "proxy";
  path = "/example";
  host = "example";
  port = 8080;
  role = "admin";
};
```

Proxy endpoints require `host` and `port`. Authentication defaults to OAuth; set `auth = null` only for an intentionally public endpoint.

Useful endpoint settings include:

- `scheme = "https"` for an HTTPS upstream
- `spoofBasic = true` when the upstream should receive shared web basic-auth credentials
- `headerUp` for additional upstream request headers
- `stripPrefix = true` or `handlePath = true` for applications that need path-prefix handling
- `type = "share"` for a static share endpoint rather than a reverse proxy

The module validates common errors during evaluation, including incomplete proxies, missing or undeclared OAuth roles, duplicate endpoint paths within a site, and duplicate domain/listen-port pairs.

## Sites And Domains

A site groups domains, endpoints, redirects, logging, and response behavior:

```nix
caddy.sites.example = {
  domains = [
    {
      host = "example.bovbel.com";
      tls = "public";
    }
  ];

  endpoints.app = {
    type = "proxy";
    path = "/";
    host = "app";
    port = 8080;
    auth = null;
  };
};
```

Domain TLS can be `public` or `tailscale`; `listenPort` can override the default listener. Prefer these declarations over hand-written Caddyfile fragments.

## Route Audit

Caddy hosts receive a generated route audit at `/etc/caddy/routes.md`. Use it to inspect the effective domains, paths, authentication, and upstreams after deployment.
