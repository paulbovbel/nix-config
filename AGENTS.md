# Agent Workflow

After every configuration change, run `nix develop --command just check`

## Repo Structure

For repository layout, module composition, and structure recommendations, see [README.md](README.md). Reference it instead of crawling the repo.

## Change Placement

- Host-specific enablement and machine settings belong in `hosts/<host>/configuration.nix`.
- Reusable NixOS behavior belongs in `modules/<name>/`, with options exposed from `options.nix` when appropriate.
- User profile changes belong under `profiles/<profile>/`; update `profiles/default.nix` when adding or changing selectable profiles.
- System profile behavior belongs under `profiles/`; profiles are selected indirectly from `hosts/default.nix` through user profile declarations.
- Globally imported modules should generally be enabled from host configs through their option namespace, not imported ad hoc.

## Repo Rules

- Do not add plaintext secrets. Use `secrets/` and `secrets.nix` for agenix-managed secrets.
- When adding stateful services on impermanent hosts, persist required state with `rootFs.persistDirectories` or `rootFs.persistFiles`.
- Server containers should generally use `podmanServer.containers`, `podmanServer.paths`, and `podmanServer.derivedEnvFiles` rather than bespoke Podman/systemd plumbing.
- Public or authenticated HTTP exposure should generally declare `caddy.endpoints` or `caddy.domains` rather than editing generated Caddyfile internals directly.
- Shared storage should use `storage.datasets` and generated storage paths instead of unmanaged hard-coded ZFS paths.
- Default packages come from the host's selected nixpkgs release; use `unstablePkgs` only intentionally and locally.
- Keep `system.stateVersion` unchanged unless the user explicitly asks to migrate it.
- Prefer to write longer scripts to sh/py files so that they're linted.
