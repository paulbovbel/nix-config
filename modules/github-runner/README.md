# GitHub Runner

The GitHub runner module operates a containerized self-hosted Actions runner for one repository.

## Requirements

The runner requires the Podman server, shared storage, and an agenix-managed registration token. Its configured labels must match the workflow labels that select it.

## Persistence

Runner work and registration state live in `storage.datasets.app.children.github-runner`. Preserve that dataset to avoid unnecessary re-registration, and remove stale registration state deliberately when replacing the runner identity.

## Troubleshooting

Inspect the host `container@github-runner.service`, then inspect `github-runner-nix-config.service` inside the container for registration or job failures. Runner state and work files are under `/storage/app/github-runner`, bind-mounted at `/var/lib/github-runner`; credentials are mounted from `/run/secrets/github-runner-token` and `/run/agenix/github-runner-ssh-key`. Jobs that remain queued after both units are healthy usually indicate a label mismatch.
