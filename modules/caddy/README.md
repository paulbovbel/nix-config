# Caddy

The Caddy module renders declarative sites and endpoints for public or Tailscale ingress. Service-owning modules should declare their routes; host configurations generally enable Caddy, define users and roles, and set host-specific site behavior.

`options.nix` is the authoritative option reference.

## Requirements

Caddy uses the Podman server for its container, storage datasets for runtime state, and agenix secrets for OAuth and basic-auth credentials. Public domains must resolve to the host before ACME certificate issuance can succeed.

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

## Persistence

The module declares `storage.datasets.app.children.caddy` and mounts it into the container. Preserve that dataset when rebuilding or recovering the host; authentication state and certificates must not be redirected to an ephemeral root path.

## Route Audit

Caddy hosts receive a generated route audit at `/etc/caddy/routes.md`. Use it to inspect the effective domains, paths, authentication, and upstreams after deployment.

## Troubleshooting

Inspect `/etc/caddy/routes.md` for the effective routes and `caddy-render.service` for validation failures. The rendered configuration and state live under `/storage/app/caddy/{Caddyfile,data,config}`; check `caddy.service`, `apps-network.service`, and the container log when those paths are present but routing fails. Authentication environment failures are reported by `podman-server-caddy-token-secret-env.service` or `podman-server-caddy-basic-auth-env.service`, while bans are managed by `fail2ban.service`.
