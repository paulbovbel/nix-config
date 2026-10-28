# Media Server

The media server module composes library services, download automation, storage datasets, ingress, and optional UPnP forwards. It is intended to run on a host that also enables the storage, Podman server, and Caddy abstractions.

Scripts and tests are owned by their submodules: `download/{scripts,tests}/` contains download automation, while `library/{scripts,tests}/` contains library processing and Plex tooling. `just check` runs both test suites.

## Library Services

`mediaServer.library.enable` runs Plex, Jellyfin, Audiobookshelf, Tautulli, and supporting library services against the shared media datasets. The service modules declare their own containers, routes, and persistent application directories.

### Audiobookshelf

Audiobookshelf is available at `/audiobookshelf` on the media site and uses its own accounts for browser and native-client access. After deployment, open that URL, create the initial administrator account, and add an audiobook library with folder `/audiobooks`. Use the same server URL in streaming clients.

The container mounts `storage.datasets.media.children.audiobooks` at `/audiobooks`. Configuration and metadata live in `config` and `metadata` beneath `storage.datasets.app.children.audiobookshelf`, which is included in the media host's application backups. Manage the container with `audiobookshelf.service`.

### Application SSO

Jellefyin, Audiobookshelf and Grimmory use native OIDC against Authentik; Caddy passes their browser and API traffic directly to the applications. Grimmory remote-header authentication is disabled. The Authentik module README describes identity provisioning and SSO integration. Configure application-side OIDC settings before relying on Google login.

## Download Automation

`mediaServer.downloads.enable` runs the torrent, video, and book download stack. Download managers write to shared download datasets, while automation services move completed content into the appropriate libraries.

### Torrent VPN

Gluetun owns the PIA WireGuard tunnel and firewall. The LinuxServer qBittorrent container and the `qbittorrent-port-sync` daemon join its network namespace through `podmanServer.containers.<name>.networkNamespaceOf`, so neither holds VPN privileges or an independent `apps` attachment. That option gives Gluetun its sharers' names as network aliases, so Caddy, Radarr and Sonarr still reach `qbittorrent:8080` unchanged; `FIREWALL_INPUT_PORTS` has to list that WebUI port, since an in-namespace port is not published and cannot be derived.

`pia-wireguard-config.service` runs the pinned [pia-wg-config fork](https://github.com/paulbovbel/pia-wg-config/tree/fix-secrets) to register a locally generated WireGuard key in `ca_toronto`, and exports the matching TLS server name for Gluetun forwarding. It reads agenix-managed `PIA_USERNAME` and `PIA_PASSWORD` from the service environment rather than command arguments, and writes only into root-owned `/run/pia-wireguard` with mode `0600` — the key and the forwarding lease never enter the Nix store. A `podmanServer.derivedEnvFiles` renderer maps those credentials and the exported server name into Gluetun's env-file; it `requires` successful provisioning, so a failed registration cannot be papered over with stale files. Gluetun's own state persists in `storage.datasets.app.children.gluetun`, which is root-only because PIA's forwarding lease includes an authentication token.

`qbittorrent-port-sync` is a Nix-built container that runs unprivileged with a read-only filesystem, no persistent storage, and no listening sockets. Every two seconds it reads Gluetun's control API at `127.0.0.1:8000/v1/portforward` and reconciles qBittorrent's loopback API, skipping redundant writes. Polling alone covers forward changes, qBittorrent restarts, and its own restarts, so there is no hook, handoff file, or systemd timer. Without a forward qBittorrent binds to loopback; with one it binds to `wg0`, which MAM also uses to register egress. qBittorrent's `ExecStartPre` hook rewrites the binding back to loopback on every start, so a tunnel without a forward fails closed, and Gluetun's firewall remains the kill switch during reconnects. The control API exposes only that one read-only route unauthenticated; all three containers share the namespace and therefore that trust boundary.

#### Recovery

Gluetun's own reconnection logic handles ordinary VPN outages without registering a new key. Gluetun upholds qBittorrent and the port-sync daemon, so stopping `gluetun.service` stops all three for maintenance.

One failure mode does not self-heal: if port forwarding fails on its first attempt (`starting port forwarding service: port forwarding for the first time`), Gluetun logs the error and never retries, so no forward appears even once the tunnel recovers. The unit stays `active` and systemd cannot see it, so check `journalctl -u gluetun | grep 'port forwarding'` whenever the port-sync daemon reports `loopback, no forward` for long, and restart `gluetun.service` to retry.

Two port-forwarding failures are worth recognising by their log line, because `pia-wg-config` picks a server without checking that it offers forwarding, and PIA rotates servers out from under it.

`API IP address not found` means the selected server runs no forwarding service. Re-register to move to another server; Gluetun follows through restart propagation:

```bash
sudo systemctl restart pia-wireguard-config.service
```

`bindPort: 401 ... "bad signature"` means Gluetun is replaying the lease in `piaportforward.json` against a server that did not issue it. Discard it and restart, which forces a fresh signature:

```bash
sudo rm -f /storage/app/gluetun/piaportforward.json
sudo systemctl restart gluetun.service
```

A successful run logs `port forwarded is <port>` and `expires in 62 days`, and the port-sync daemon follows with `Bound qBittorrent to wg0 port <port>`. Note that `SERVER_NAMES` need not appear in Gluetun's own server list: `pia-wg-config` reads PIA's v4 list and Gluetun embeds v6, so the names routinely differ, and forwarding still works. If provisioning failed before any container started, `sudo systemctl restart gluetun.service` runs it again. Inspect `journalctl -u pia-wireguard-config -u gluetun -u qbittorrent -u qbittorrent-port-sync` for diagnostics; the generator's stdout is discarded because it prints the WireGuard config, so do not reintroduce it or copy the generated files into logs.

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
