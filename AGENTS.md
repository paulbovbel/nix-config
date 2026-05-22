# Agent Workflow

After every configuration change, always run both commands:

1. `nix flake check`
2. `nixos-rebuild dry-run --flake .#white-tower`

Treat this as a required verification step before considering the change done.

## Repo Structure

For repository layout, module composition, and structure recommendations, see [README.md](README.md). Reference it instead of crawling the repo.
