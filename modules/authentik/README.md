# Authentik

Authentik provides Google-backed sign-in, Caddy forward authentication, and native OIDC applications declared through `authentik.applications`. Enable `authentik.enable` and set `authentik.domain` on the ingress host.

The pinned server and worker share PostgreSQL and use the embedded proxy outpost. State lives in `storage.datasets.app.children.authentik` and `authentik-db`, included in the media host's application backups. Restore both datasets together. Runtime keys, the database password, the initial `akadmin` password, and confidential application client secrets are generated once in `authentik/secrets/runtime.env` with root-only permissions. Existing Google credentials come from the agenix-managed `google-oauth-env` secret.

## Migration and first deployment

1. Add `https://auth.bovbel.com/source/oauth/callback/google/` to the existing Google OAuth client's authorized redirect URIs. The host's DDNS configuration publishes `auth.bovbel.com`.
2. While still signed into Grimmory as an administrator, configure its OIDC settings below and retain that browser session or establish a local administrator login before switching off remote auth.
3. Deploy the media host. The worker applies the `nix-config identity and applications` blueprint after its default flows. Initial database migration can take several minutes. Check the blueprint status in **Customization → Blueprints**.
4. Open `https://auth.bovbel.com/`. The Google source links only existing users by email; public enrollment is disabled. `caddy.users` provisions these users and their role groups. The local `akadmin` account uses the generated bootstrap password; retrieve it over an administrative SSH session from the root-only runtime environment file when needed.
5. Complete the application's own authentication settings as below. These settings are stored by the applications in their databases, not exposed as container environment variables. The Authentik providers are provisioned automatically, but application-side settings must be saved through their admin interfaces.

The blueprint owns the listed users' memberships and provider configuration. Update them in Nix rather than the UI. `authentik.adminUsers` controls membership in a dedicated Authentik superuser group; application `admin` roles do not grant identity-provider administration. Removing a user from `caddy.users` denies Google source authentication and new application authorization; revoke existing Authentik/outpost sessions and application sessions when removing access. OIDC applications issue their own sessions, so identity-provider logout or removal does not automatically revoke every application token.

## Caddy

`auth = "oauth"` now means Authentik forward authentication. A single-application proxy provider is generated for each protected domain, including the Tailscale domain. Caddy checks the endpoint's required `role` against authenticated groups, preserving mixed user/admin paths on the media site. Incoming identity headers are removed before the check. Authentik callback/outpost paths bypass forward authentication.

The Caddy Security plugin, Google credentials in Caddy, and Caddy token signing secret are no longer used. Basic-auth routes continue to work as before.

## Audiobookshelf

In **Settings → Authentication**, enable OpenID Connect:

| Setting | Value |
| --- | --- |
| Issuer | `https://auth.bovbel.com/application/o/audiobookshelf/` |
| Discovery URL | `https://auth.bovbel.com/application/o/audiobookshelf/.well-known/openid-configuration` |
| Client ID | `audiobookshelf` |
| Client secret | `AUDIOBOOKSHELF_CLIENT_SECRET` from the protected runtime environment file, or the Authentik provider UI |
| Scopes | `openid profile email` |
| Signing algorithm | `RS256` |
| Match existing users by | Email |

Registered redirects are `https://media.bovbel.com/audiobookshelf/auth/openid/callback` and `https://media.bovbel.com/audiobookshelf/auth/openid/mobile-redirect`. Use the public media URL in clients. Keep local login enabled while testing. Set library permissions in Audiobookshelf; enable auto-registration only if you want all allowlisted Authentik users to get application accounts.

## Grimmory

Grimmory uses Authorization Code with PKCE as a public client, without a client secret. The callback for the pinned Grimmory version is `/grimmory/oauth2-callback`, not the older BookLore `/api/oidc` callback.

In **Settings → Authentication**, configure and enable OIDC:

| Setting | Value |
| --- | --- |
| Provider name | Authentik |
| Client ID | `grimmory` |
| Client secret | Leave empty (public PKCE client) |
| Issuer URI | `https://auth.bovbel.com/application/o/grimmory/` |
| Scopes | `openid profile email groups offline_access` |
| Username claim | `email` |
| Email claim | `email` |
| Display name claim | `name` |
| Groups claim | `groups` |

The registered redirect is `https://media.bovbel.com/grimmory/oauth2-callback`. Enable **Allow local account linking** to link the existing remote-auth accounts by their email-based usernames; this preserves their library state. Auto-provisioning can be enabled for new allowlisted users. Configure Grimmory's OIDC group mappings for the `admin` and `user` groups and intended library permissions. Caddy no longer injects a user identity or requires a separate browser login on this route. Kobo continues using its application token on the existing endpoint.

If the issuer resolves to a private address from inside Grimmory, its OIDC SSRF filter may reject discovery. Prefer public DNS/routing; enable `OIDC_ALLOW_UNSAFE_HOSTS` only intentionally for a private issuer deployment.

## Operations

Inspect `authentik.service`, `authentik-worker.service`, `authentik-db.service`, and `podman-server-authentik-env.service`. Restart containers through their owning systemd services. Authentik images are pinned and automatic updates disabled so server and worker upgrade together.

Check blueprint status in the admin UI and the worker journal, and check each application's discovery document before testing browser login. Google sign-in requires the external callback registration and a real browser test.
