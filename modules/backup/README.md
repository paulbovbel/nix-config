# Backup

The backup module schedules rsync pushes from named local paths to SSH targets. A target can receive several independently named paths beneath a shared remote root.

## Requirements

Each target must be reachable over SSH with an agenix-managed identity and permit rsync writes beneath `backup.remoteRoot`. Persist the identity on impermanent hosts. Verify source datasets are mounted before the timer runs; otherwise rsync may back up empty mountpoints.

## Minimal Configuration

```nix
backup = {
  identityFile = "/run/agenix/backup-key";
  targets."backup@example.com".paths.documents.source = "/storage/documents";
};
```

This backs up documents daily to `nixos/documents` on the SSH target. Declare the `backup-key` agenix secret separately.

## Persistence

Each target stores its accepted host key under `/var/lib/backup-<target>/known_hosts`. The module declares these state directories through `rootFs.persistDirectories` so they survive impermanent reboots.

## Troubleshooting

Inspect `backup-<target>.service` and `.timer` for transfer statistics and failures.
