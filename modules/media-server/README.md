# Media Server

The media server module composes library services, download automation, storage datasets, ingress, and optional UPnP forwards. It is intended to run on a host that also enables the storage, Podman server, and Caddy abstractions.

## Library Services

`mediaServer.library.enable` runs Plex, Jellyfin, Audiobookshelf, Tautulli, and supporting library services against the shared media datasets. The service modules declare their own containers, routes, and persistent application directories.

### Audiobookshelf

Audiobookshelf is available at `/audiobookshelf` on the media site and uses its own accounts for browser and native-client access. After deployment, open that URL, create the initial administrator account, and add an audiobook library with folder `/audiobooks`. Use the same server URL in streaming clients.

The container mounts `storage.datasets.media.children.audiobooks` at `/audiobooks`. Configuration and metadata live in `config` and `metadata` beneath `storage.datasets.app.children.audiobookshelf`, which is included in the media host's application backups. Manage the container with `audiobookshelf.service`.

### Application SSO

Audiobookshelf and Grimmory use native OIDC against Authentik; Caddy passes their browser and API traffic directly to the applications. Grimmory remote-header authentication is disabled. The Authentik module README documents provider URLs, application-side settings, and linking existing Grimmory accounts. Configure those settings before relying on Google login after migration.

## Download Automation

`mediaServer.downloads.enable` runs the torrent, video, and book download stack. Download managers write to shared download datasets, while automation services move completed content into the appropriate libraries.

qBittorrent temporarily overlays `/usr/local/bin/tools.sh` with the pinned version from [Binhex PR #57](https://github.com/binhex/arch-int-vpn/pull/57) at commit `3f6f0f83a11db712a3781035f9644af789b3f568`. This adds PIA's v2 token API, request timeouts, and working endpoint fallback/retries. The read-only mount survives container recreation; remove the overlay once the upstream image includes the fix.

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
