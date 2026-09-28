# Backup

The backup module schedules rsync pushes from named local paths to SSH targets. A target can receive several independently named paths beneath a shared remote root.

## Requirements

Each target must be reachable over SSH with an agenix-managed identity and permit rsync writes beneath `backup.remoteRoot`. Persist the identity on impermanent hosts. Verify source datasets are mounted before the timer runs; otherwise rsync may back up empty mountpoints.

## Troubleshooting

Inspect `backup-<target>.service` and `.timer`. Each target stores its accepted host key under `/var/lib/backup-<target>/known_hosts`.
