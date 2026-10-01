# Storage

The storage module declares a nested tree of shared ZFS datasets. Each declaration produces a mount path that other modules consume, keeping dataset ownership, ZFS properties, and snapshot policy in one place.

## Requirements

The ZFS pool must be importable at boot. Consumers should use generated paths such as `config.storage.datasets.media.children.movies.path` instead of constructing mountpoints themselves.

`storage.pool` selects the shared pool (default `storage`). `storage.defaultOwner`
and `storage.defaultGroup` default to `root` independently of Podman; hosts can
choose application ownership, and individual datasets can override it. Child
datasets use these global defaults rather than inheriting a parent's owner.

Enabling storage creates no workload datasets. Hosts declare backup datasets and
site-wide snapshot policy; enabled workloads declare their own state datasets.

## Invariants

- Child dataset mount paths are derived from their position in the declaration tree.
- Snapshot settings inherit only through values explicitly assigned by module composition.

## Recovery

Import the pool and verify dataset mountpoints before starting dependent services. If a path is unexpectedly empty, check whether the dataset is mounted before writing new data into the underlying directory.
