# Tailnet

## Device roles

Hosts default to one role derived from users with nonempty `userProfiles.<user>`:

- Any selected user with `accounts.<user>.isKid = true`: `tag:kids-device`.
- Otherwise: `tag:adult-device`.

Roles apply to the whole machine, regardless of who is logged in. Adult and kids
tags must remain mutually exclusive because Tailscale grants are additive.
Explicit `tailnet.tags` replaces the derived default for infrastructure hosts.
The common profile enables
`tailnet.enable`; enrollment and state persistence live in this module. The MagicDNS suffix is
configured through `tailnet.domain` in `hosts/site.nix`.

## Access policy

`hosts/site.nix` declares the native Tailscale policy under `tailnet.policy`:
groups, tag ownership, grants, node attributes, auto-approval, and access tests.
`tailnet.containerGrants` separately selects a host, container names, and a grant
without `ip`. The generator appends grants using those containers' declared
tailnet ports, deduplicating ports and omitting empty grants. Unknown hosts or
containers are errors: remove disabled containers from the selection explicitly.
The flake evaluates site configuration once and passes it to the generator.
Host tags must be declared in the policy; ownership is never inferred. Access
tests remain independent site assertions. See `hosts/site.nix` for the deployed
access rules, tag ownership, and DNS attributes.

## Credentials and deployment

Enrollment uses `secrets/common/tailscale-oauth-authkey.age`: one raw OAuth client
secret with **Auth keys: Write**, scoped to the advertised tags. Configure
`tagOwners` in the site policy to permit enrollment with those tags.

Policy deployment uses the separate `/run/agenix/tailscale-mcp-env` credential
with **Policy file: Write** and its required scopes. See
[credential setup](../../profiles/common/home/README.md).

From `nix develop`:

```bash
just tailnet-policy        # Print the generated JSON file path
just tailnet-policy-apply  # Validate policy/tests, then apply through the API
just switch <host>         # Deploy enrollment configuration separately
```

The apply script uses `curl` and `jq`; it does not require OpenCode. Policy
deployment does not retag existing devices. When changing roles, update OAuth
tag scopes and device tags before removing their old policy definitions.
