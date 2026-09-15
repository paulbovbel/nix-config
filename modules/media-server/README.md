# Media Server

The media server module composes library services, download automation, storage datasets, ingress, and optional UPnP forwards. It is intended to run on a host that also enables the storage, Podman server, and Caddy abstractions.

## Requirements

Enable shared storage and the Podman server before enabling library or download services. Caddy is required for declared web routes, agenix supplies service credentials, and optional router exposure uses the UPnP module.

Library and download state is placed in declared storage datasets. Public routes and port forwards are derived by the owning service modules rather than duplicated in host configuration.

## Persistence

Application databases and configuration live under `storage.datasets.app`; media and download content live under `storage.datasets.media` and related datasets. Preserve and mount both trees before starting containers.

## Troubleshooting

Inspect the service-specific unit first, such as `jellyfin.service`, `plex.service`, `qbittorrent.service`, `sonarr.service`, `radarr.service`, `readarr.service`, or `shelfmark.service`. Application state is under `/storage/app/<service>`, downloads under `/storage/downloads`, and libraries under `/storage/media/{audiobooks,books,comics,movies,tv,youtube}`; verify the relevant mounts and ownership before changing container settings. For automation failures, inspect units such as `qbittorrent-config.service`, `cleanup-downloads.service`, `download-popular-videos.service`, or `myanonamouse-update.service`; generated environment files are under `/run/podman-server`.
