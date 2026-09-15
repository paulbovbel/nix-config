# Backup

The backup module schedules rsync pushes from named local paths to SSH targets. A target can receive several independently named paths beneath a shared remote root.

## Requirements

Each target must be reachable over SSH with the configured identity, and every source path must be mounted before its timer runs. The remote account must permit rsync writes beneath `backup.remoteRoot`.

The SSH identity should be supplied through agenix and persisted when the host uses an impermanent root. Confirm that each source path is mounted before relying on a scheduled backup.

## Persistence

Systemd stores per-target service state locally, but the durable backup is the remote rsync tree. Persist the SSH identity through agenix and ensure source datasets are mounted rather than backing up empty mountpoint directories.

## Troubleshooting

Inspect the generated `backup-<target>.service` and `.timer`; current examples are `backup-de4856-de4856-rsync-net.service` and `backup-pbovbel-offsite.service`. Each target stores its accepted host key under `/var/lib/backup-<target>/known_hosts`. Verify every configured `/storage/app/<service>`, `/storage/backup`, or `/storage/media/<library>` source is mounted before running the unit, since rsync cannot distinguish an empty mountpoint from an empty dataset.
