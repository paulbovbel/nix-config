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

- Self-hosted validation accepts pushes to `main` and PR branches within this repository. Branch writers are trusted with access to the runner's SSH key. Fork PRs skip self-hosted validation; review external changes before transferring them to a repository branch. Skipped jobs are not proof of validation and may satisfy required-check rules.
- Configure branch protection to require **check**, **Evaluate and test**, and each **Host (<host>)** check. Update required checks when the CI host inventory changes; the aggregate **CI** status has been removed.
- Successful `main` runs publish host closures and documentation. Cache credentials use the `ATTIC_TOKEN` Actions secret. Dependabot combines flake inputs, GitHub Actions, and shared container image catalog updates into one weekly `dependencies` multi-ecosystem PR. Docker updates refresh digests without changing tag channels.
- Logs and job durations are available in GitHub Actions. Workflow definitions live in `.github/workflows/` and are checked by `just check`.
