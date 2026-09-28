# Media Server

The media server module composes library services, download automation, storage datasets, ingress, and optional UPnP forwards. It is intended to run on a host that also enables the storage, Podman server, and Caddy abstractions.

## Library Services

`mediaServer.library.enable` runs Plex, Jellyfin, Tautulli, and supporting library services against the shared media datasets. The service modules declare their own containers, routes, and persistent application directories.

## Download Automation

`mediaServer.downloads.enable` runs the torrent, video, and book download stack. Download managers write to shared download datasets, while automation services move completed content into the appropriate libraries.

### Popular Videos

`mediaServer.downloads.popularVideos.channels` selects a fixed number of popular videos from each configured YouTube channel, optionally limited by duration. The calendar option controls the systemd timer that refreshes those selections.

## Network Exposure

`mediaServer.upnp.enable` allows services that require direct public ports to declare UPnP forwards. Web interfaces remain exposed through Caddy.

## Requirements

Library and download services need shared storage and the Podman server. Web routes need Caddy; credentials come from agenix. Service modules declare their own routes and optional UPnP forwards.

## Persistence

Application databases and configuration live under `storage.datasets.app`; media and download content live under `storage.datasets.media` and related datasets. Preserve and mount both trees before starting containers.

## Troubleshooting

Inspect the affected service unit and verify its mounts and ownership: application state is under `/storage/app/<service>`, downloads under `/storage/downloads`, and libraries under `/storage/media`. For automation failures, check the relevant job's unit and its generated environment file under `/run/podman-server`.
