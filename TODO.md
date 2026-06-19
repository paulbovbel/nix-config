# TODO

## Backups

- Add Syncthing data to rsync.net backups once Syncthing is enabled and the sync layout is finalized.

## Syncthing

- Set up Syncthing across all machines.
- Decide which datasets/directories are shared between desktop, laptop, and media host.

## Service Isolation

- Create dedicated users for different media-server services.
- Unify path, ownership, and permission handling between units.

## Service Hardening

- Harden `ddns-update`.
- Harden `upnp-update`.
- Harden `attic-cache-bootstrap`.
- Harden `attic-watch-store`.
- Harden Podman server derived environment file renderers.
- Review whether `atticd` can take additional sandboxing beyond its current `ReadWritePaths`.
- Review whether `llama-cpp-proxy` can be hardened without breaking GPU, DBus, or systemd interactions.

## Containers

- Keep global `--no-healthcheck` in Quadlet and add a `podman-server-healthcheck` timer/service that reports unhealthy containers without failing activation.
