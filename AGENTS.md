# Agent Workflow

After every change, run `nix develop --command just check`.

For Nix changes, also evaluate or build the affected host, package, or check. Use `nix develop --command just nix-test` only when full flake-check validation, including integration tests, is specifically needed; CI runs it for every change.

## Repo Structure

For repository layout, module composition, and structure recommendations, see [README.md](README.md). Reference it instead of crawling the repo.

## Change Placement

- Host-specific enablement and machine settings belong in `hosts/<host>/configuration.nix`.
- Reusable NixOS behavior belongs in `modules/<name>/`, with options exposed from `options.nix` when appropriate.
- User profile changes belong under `profiles/<profile>/`; update `profiles/default.nix` when adding or changing selectable profiles.
- System profile behavior belongs under `profiles/`; `profiles/module.nix` composes typed `userProfiles` selections from `hosts/<host>/configuration.nix`. Keep system imports static and gate profile settings with `lib.mkIf`.
- Globally imported modules should generally be enabled from host configs through their option namespace, not imported ad hoc.

## Repo Rules

- Do not add plaintext secrets. Use `secrets/` and `agenix-rules.nix` for agenix-managed secrets.
- When adding stateful services on impermanent hosts, persist required state with `rootFs.persistDirectories` or `rootFs.persistFiles`.
- Server containers should generally use `podmanServer.containers`, `podmanServer.paths`, and `podmanServer.derivedEnvFiles` rather than bespoke Podman/systemd plumbing.
- Never use `podman restart`; restart containers through their owning systemd service with `systemctl restart <name>.service`.
- Public or authenticated HTTP exposure should generally declare `caddy.sites.<name>.endpoints` or `caddy.sites.<name>.domains` rather than editing generated Caddyfile internals directly.
- Shared storage should use `storage.datasets` and generated storage paths instead of unmanaged hard-coded ZFS paths.
- Default packages come from the host's selected nixpkgs release; use `unstablePkgs` only intentionally and locally.
- Keep `system.stateVersion` unchanged unless the user explicitly asks to migrate it.
- Prefer to write longer scripts to sh/py files so that they're linted.
- Keep non-Nix scripts in `modules/<name>/scripts/` and all tests and test helpers in `modules/<name>/tests/`. Documentation, deployment, and monitoring tooling also belong under their owning module directories.
- For composite modules, keep scripts and tests under the owning submodule (for example, `modules/media-server/download/{scripts,tests}/`). Profile-only Home Manager scripts may live in `profiles/<profile>/home/scripts/`.
