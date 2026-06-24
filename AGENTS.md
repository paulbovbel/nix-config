# Agent Workflow

After every configuration change, run the full check suite:

1. `just check`
2. `just dry-run <host>`

Known hosts are `white-tower`, `pbovbel-dell`, and `media`.

## Repo Structure

For repository layout, module composition, and structure recommendations, see [README.md](README.md). Reference it instead of crawling the repo.

## Change Placement

- Host-specific enablement and machine settings belong in `hosts/<host>/configuration.nix`.
- Reusable NixOS behavior belongs in `modules/<name>/`, with options exposed from `options.nix` when appropriate.
- User Home Manager changes belong under `users/`; update `users/default.nix` when adding or changing selectable user profiles.
- System profile behavior belongs under `profiles/`; profiles are selected indirectly from `hosts/default.nix` through user profile declarations.
- Globally imported modules should generally be enabled from host configs through their option namespace, not imported ad hoc.

## Available Module Namespaces

Host-facing modules currently expose these top-level namespaces:

- `atticCache`
- `caddy`
- `ddns`
- `gameServer`
- `rootZfs`
- `llamaCpp`
- `mediaServer`
- `nvidia`
- `podmanServer`
- `storage`
- `syncthing`
- `upnp`
- `cockpit.enable` and `smokeping.enable` from monitor modules

## Repo Rules

- Do not add plaintext secrets. Use `secrets/` and `secrets.nix` for agenix-managed secrets.
- When adding stateful services on impermanent hosts, persist required state with `rootZfs.persistDirectories` or `rootZfs.persistFiles`.
- Server containers should generally use `podmanServer.containers`, `podmanServer.paths`, and `podmanServer.derivedEnvFiles` rather than bespoke Podman/systemd plumbing.
- Public or authenticated HTTP exposure should generally declare `caddy.endpoints` or `caddy.domains` rather than editing generated Caddyfile internals directly.
- Shared storage should use `storage.datasets` and generated storage paths instead of unmanaged hard-coded ZFS paths.
- Default packages come from the host's selected nixpkgs release; use `unstablePkgs` only intentionally and locally.
- Keep `system.stateVersion` unchanged unless the user explicitly asks to migrate it.
- Prefer to write longer scripts to sh/py files so that they're linted.
