# Automatic Upgrades

The automatic upgrade module builds and activates guarded NixOS updates from the configuration branch recorded in the running system.

## Requirements

The configured repository must be reachable with the agenix-managed `nix-config-auto-upgrade-key`. Email reporting requires `programs.msmtp.enable = true`, and deployments must record their source branch through `NIX_CONFIG_BRANCH`; the `just switch` and `just boot` recipes do this automatically.

## Safety Gates

Before activation, the service verifies that the active generation came from a clean revision and that the candidate revision descends from it. It also refuses to activate while an unlocked graphical session exists. If kernel, initrd, or kernel modules change outside the 03:00 to 05:00 reboot window, activation is deferred instead of leaving the running and booted systems inconsistent.

When a recorded feature branch no longer exists remotely, the service transitions to `autoUpgrade.branch`, which defaults to `main`.

## Persistence

Upgrade reports that cannot be sent immediately are queued under `/var/lib/auto-upgrade/reports` and retried hourly. The module persists `/var/lib/auto-upgrade` on impermanent hosts.

## Troubleshooting

Inspect `nixos-upgrade.service` and `nixos-upgrade.timer` for revision, session, build, and activation failures; runtime build state and the outcome are under `/run/nixos-upgrade`. Check `/run/agenix/nix-config-auto-upgrade-key` when repository access fails. Unsent reports remain in `/var/lib/auto-upgrade/reports`; inspect `auto-upgrade-report-retry.service` and `.timer` plus the msmtp configuration when that directory does not drain.
