# Caddy

The Caddy module renders declarative sites and endpoints for public or Tailscale ingress. Service-owning modules should declare their routes; host configurations generally enable Caddy and set host-specific site behavior. Declare identities and role groups through `authentik.users` and `authentik.roles`.

## Requirements

Caddy uses the Podman server for its container, storage datasets for runtime state, and agenix secrets for basic-auth credentials. NixOS ACME uses the existing AWS secret for Route53 DNS validation; Caddy runs the stock package without DNS plugins. OAuth routes require the Authentik module; it owns Google credentials, identities, and the embedded forward-auth outpost.

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

Proxy endpoints require `host` and `port`. Authentication defaults to Authentik forward auth (`auth = "oauth"`); `role` selects the required Authentik group. Use `auth = null` for public endpoints or applications enforcing their own authentication, including native OIDC clients.

When Authentik is enabled, endpoints appear as application dashboard tiles using a public site domain (or the first domain when none is public). Override `dashboard.name` and `dashboard.iconUrl` for presentation, or set `dashboard.enable = false` for protocol-only endpoints. OAuth tile visibility follows the endpoint's required role; native OIDC entries with the same launch URL are reused.

Icons default to a lookup in Homarr's pinned catalogue using the endpoint name: light artwork for dark backgrounds, SVG before PNG, then a folder fallback. Set `dashboard.iconName` for a different Homarr asset or `dashboard.iconUrl` for custom artwork.

Protected domains automatically provision Authentik proxy providers. Shared helpers in `modules/authentik/lib.nix` keep domain selection/formatting, the outpost upstream, and identity-header handling consistent. The generated `authentik-auth` snippet performs authentication and per-route role checks before path-prefix stripping; application upstreams do not receive identity headers, while protocol headers such as `X-Authentik-CSRF` are preserved.

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

Public site hostnames are also DNS aliases for Caddy on the shared Podman `apps`
network. Containers can use the same public HTTPS URLs as browsers, including OIDC
discovery and token endpoints, while connecting directly to Caddy internally.
Aliases are deduplicated across sites; custom listener ports remain part of the URL.

## Persistence

Preserve `storage.datasets.app.children.caddy` for Caddy runtime state and `/var/lib/acme` for certificates and ACME account keys. The module declares ACME persistence through `rootFs.persistDirectories`.

## Certificates

`security.acme.certs.caddy` issues a certificate for the host's base domain and its wildcard, adding any public site names not covered by that wildcard. Route53 DNS validation works for Tailscale-only sites without exposing HTTP ports to the internet. The `aws-access-env` secret supplies AWS credentials and `AWS_HOSTED_ZONE_ID` directly to Lego and DDNS.

The certificate directory is mounted read-only at `/certs` in both Caddy and its configuration validator. NixOS creates a temporary self-signed certificate at first boot so Caddy can start, then obtains the trusted certificate. Successful issuance and renewal force a Caddy reload to pick up the changed certificate files. Tailscale TLS continues to use `tailscaled` directly.

On the first deployment, NixOS requests a new certificate rather than reusing Caddy's previous certificate store. Check `acme-order-renew-caddy.service` for successful issuance before relying on browser-trusted HTTPS.

## Route Audit

Caddy hosts receive a generated route audit at `/etc/caddy/routes.md`. Use it to inspect the effective domains, paths, authentication, and upstreams after deployment.

## Troubleshooting

Inspect `/etc/caddy/routes.md` and `caddy-render.service` first. For routing failures check `caddy.service`, `apps-network.service`, and the container log. For authentication failures check `authentik.service`, `authentik-worker.service`, or `podman-server-caddy-basic-auth-env.service`.
