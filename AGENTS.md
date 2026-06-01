# Agent Workflow

After every configuration change, always run the full check suite:

1. `just all`

Treat this as a required verification step before considering the change done.

For refactor-only changes where behavior is intended to remain identical, also verify the final system derivation is unchanged by comparing:

- current: `readlink -f /run/current-system`
- next: `nix build --no-link --print-out-paths .#nixosConfigurations.white-tower.config.system.build.toplevel`

If the two store paths match, the refactor is a true no-op at the toplevel derivation.

## Repo Structure

For repository layout, module composition, and structure recommendations, see [README.md](README.md). Reference it instead of crawling the repo.
