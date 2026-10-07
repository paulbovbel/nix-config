# Authentik

Authentik provides Google-backed sign-in, Caddy forward authentication, and native OIDC applications declared through `authentik.applications`. Enable `authentik.enable` and set `authentik.domain` on the ingress host.

## Identity and configuration

`authentik.users` and `authentik.roles` provision the login allowlist and group memberships. `authentik.adminUsers` separately grants identity-provider administration. Google links existing users by email; public enrollment is disabled. Register `https://<authentik.domain>/source/oauth/callback/google/` with Google and supply credentials through the agenix-managed `google-oauth-env` secret.

The worker applies a generated blueprint that owns users, memberships, and providers. Make configuration changes in Nix. Removing a user prevents new authorization; revoke existing identity-provider and application sessions separately.

## Integration

Caddy endpoints with `auth = "oauth"` automatically provision forward-auth providers. Caddy checks each endpoint's required role and strips identity headers before proxying to applications.

Caddy endpoints also generate dashboard tiles with names, icons, and role-aware visibility. Public URLs are preferred, native OIDC entries are reused, and `dashboard.enable = false` excludes non-browser endpoints. Dashboard links do not replace application or Caddy access controls.

`authentik.applications` declares native OIDC clients, scopes, and redirect URIs; configure the corresponding client settings in each application. Confidential clients generate persistent secrets by default, while public clients do not. A dedicated email mapping marks allowlisted identities as verified without changing Authentik's managed mapping.

## Operations

Server and worker share PostgreSQL and use the embedded outpost. Persist and restore `storage.datasets.app.children.authentik` and `authentik-db` together. Generated credentials live in root-only files beneath the Authentik dataset's `secrets/` directory; client secrets are persisted individually and reuse existing credentials during migration. Images are pinned so server and worker upgrade together.

Inspect `authentik.service`, `authentik-worker.service`, and `authentik-db.service`, plus blueprint status in the admin UI. Restart containers through their systemd services.

Run `nix develop --command just authentik-test` for the minimal NixOS VM check of provisioning, credentials, dashboard links, visibility, and blueprint reconciliation. CI includes it in the flake checks. Google login also requires a browser smoke test.

The VM uses separately pinned offline Authentik and PostgreSQL archives in
`tests/blueprint.nix`. Refresh their image digests and Nix archive hashes manually
when updating the fixtures. Dependabot updates the production image catalog,
not these fixtures; a passing VM test does not certify a newer production image.
