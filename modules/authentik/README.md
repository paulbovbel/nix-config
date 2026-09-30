# Authentik

Authentik provides Google-backed sign-in, Caddy forward authentication, and native OIDC applications declared through `authentik.applications`. Enable `authentik.enable` and set `authentik.domain` on the ingress host.

## Identity and configuration

`authentik.users` and `authentik.roles` provision the login allowlist and group memberships. `authentik.adminUsers` separately grants identity-provider administration. Google links existing users by email; public enrollment is disabled. Register `https://<authentik.domain>/source/oauth/callback/google/` with Google and supply credentials through the agenix-managed `google-oauth-env` secret.

The worker applies a generated blueprint that owns users, memberships, and providers. Make configuration changes in Nix. Removing a user prevents new authorization; revoke existing identity-provider and application sessions separately.

## Integration

Caddy endpoints with `auth = "oauth"` automatically provision forward-auth providers. Caddy checks each endpoint's required role and strips identity headers before proxying to applications.

`authentik.applications` declares native OIDC clients, scopes, and redirect URIs; configure the corresponding client settings in each application. Confidential clients generate persistent secrets by default, while public clients do not. A dedicated email mapping marks allowlisted identities as verified without changing Authentik's managed mapping.

## Operations

Server and worker share PostgreSQL and use the embedded outpost. Persist and restore `storage.datasets.app.children.authentik` and `authentik-db` together. Generated credentials live in the root-only `authentik/secrets/runtime.env` beneath the Authentik dataset. Images are pinned so server and worker upgrade together.

Inspect `authentik.service`, `authentik-worker.service`, and `authentik-db.service`, plus blueprint status in the admin UI. Restart containers through their systemd services.

Run `nix develop --command just authentik-test` for disposable-container checks of grants, email claims, and blueprint reconciliation. Google login also requires a browser smoke test.
