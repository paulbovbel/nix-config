# GitHub Runner

The GitHub runner module operates a containerized self-hosted Actions runner for one repository.

## Requirements

The runner requires shared storage and an agenix-managed registration token. Its configured labels must match the workflow labels that select it.

Private flake inputs use the existing agenix-managed SSH key, mounted read-only at `/run/agenix/github-runner-ssh-key` and selected by the runner's `GIT_SSH_COMMAND`.

## Persistence

Runner work and registration state live in `storage.datasets.app.children.github-runner`. Preserve that dataset to avoid unnecessary re-registration, and remove stale registration state deliberately when replacing the runner identity.

## Troubleshooting

Inspect the host `container@github-runner.service`, then inspect `github-runner-nix-config.service` inside the container for registration or job failures. Runner state and work files are under `/storage/app/github-runner`, bind-mounted at `/var/lib/github-runner`; the registration token is mounted from `/run/secrets/github-runner-token`. Jobs that remain queued after both units are healthy usually indicate a label mismatch.

## CI workflow

- Self-hosted validation accepts pushes to `main` and PR branches within this repository. Branch writers are trusted with access to the runner's SSH key. Fork PRs receive a failing `CI` status without running on the server; review external changes before transferring them to a repository branch.
- Configure branch protection to require **CI**, which passes only when all validation stages succeed.
- Successful `main` runs publish host closures and documentation. Cache credentials use the `ATTIC_TOKEN` Actions secret; dependency-update PRs use `DEPENDENCY_UPDATE_TOKEN`.
- Logs and job durations are available in GitHub Actions. Workflow definitions live in `.github/workflows/` and are checked by `just check`.
