# Tailnet

## Device roles

Hosts default to one role derived from users with nonempty `userProfiles.<user>`:

- Any selected user with `accounts.<user>.isKid = true`: `tag:kids-device`.
- Otherwise: `tag:adult-device`.

Roles apply to the whole machine, regardless of who is logged in. Adult and kids
tags must remain mutually exclusive because Tailscale grants are additive.
Explicit `tailnet.tags` replaces the derived default for infrastructure hosts.
The base profile enables
`tailnet.enable`; enrollment and state persistence live in this module. The MagicDNS suffix is
configured through `tailnet.domain` in `hosts/site.nix`.

## Access policy

`hosts/tailnet-policy.nix` declares the native Tailscale `policy`:
groups, tag ownership, grants, node attributes, auto-approval, and access tests.
`containerGrants` separately selects a host, container names, and a grant
without `ip`. The generator appends grants using those containers' declared
tailnet ports, deduplicating ports and omitting empty grants. Unknown hosts or
containers are errors: remove disabled containers from the selection explicitly.
The flake imports this plain data file directly into the generator.
Enabled host tags must be declared in the policy; ownership is never inferred. Access
tests remain independent site assertions. See `hosts/tailnet-policy.nix` for the deployed
access rules, tag ownership, and DNS attributes.

## Credentials and deployment

Enrollment uses `secrets/common/tailscale-oauth-authkey.age`: one raw OAuth client
secret with **Auth keys: Write**, scoped to the advertised tags. Configure
`tagOwners` in the site policy to permit enrollment with those tags.

Policy deployment requires explicitly exported `TAILSCALE_OAUTH_CLIENT_ID` and
`TAILSCALE_OAUTH_CLIENT_SECRET` for a dedicated policy-write OAuth client.
The apply script does not load credential files.

CI validates and applies policy after successful checks and host builds on
`main`. Configure GitHub Actions secrets `TAILSCALE_OAUTH_CLIENT_ID` and
`TAILSCALE_OAUTH_CLIENT_SECRET` with a dedicated policy-write OAuth client.
Select **Policy file: Write** (`policy_file`), **Devices → Core: Read**
(`devices:core:read`), and **Devices → Posture attributes: Write**
(`devices:posture_attributes`).
