# Storage

The storage module declares a nested tree of shared ZFS datasets. Each declaration produces a mount path that other modules consume, keeping dataset ownership, ZFS properties, and snapshot policy in one place.

## Requirements

The ZFS pool must be importable at boot. Consumers should use generated paths such as `config.storage.datasets.media.children.movies.path` instead of constructing mountpoints themselves.

## Invariants

- Child dataset mount paths are derived from their position in the declaration tree.
- Snapshot settings inherit only through values explicitly assigned by module composition.

## Recovery

Import the pool and verify dataset mountpoints before starting dependent services. If a path is unexpectedly empty, check whether the dataset is mounted before writing new data into the underlying directory.
