# TODO

## Backups

- Add Syncthing data to rsync.net backups once Syncthing is enabled and the sync layout is finalized.

## Syncthing

- Set up Syncthing across all machines.
- Decide which datasets/directories are shared between desktop, laptop, and media host.

## Service Isolation

- Create dedicated users for different media-server services.
- Unify path, ownership, and permission handling between units.

## Containers

- Keep global `--no-healthcheck` in Quadlet and add a `podman-server-healthcheck` timer/service that reports unhealthy containers without failing activation.

## netboot

- currently multiple netboot loaders maybe installed to EFI, and only non-legacy is ever registered with bootctl

## root-zfs

any way to assert against switching any rootZfs parameters post initial install?
