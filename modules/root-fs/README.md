# Root Filesystem

The root filesystem module defines a shared Disko layout for Btrfs and ZFS hosts. It can create a new encrypted disk layout or mount explicitly supplied existing partitions, and optionally resets the root filesystem at boot while preserving declared state.

## Requirements

New layouts require a stable disk identifier and are applied through Disko. Existing layouts require explicit EFI, root, and optional swap partition paths. Encrypted installations also require the host's early-boot unlock strategy to be available before deployment.

## Minimal Configuration

```nix
rootFs = {
  enable = true;
  backend = "zfs";
  diskId = "/dev/disk/by-id/nvme-example";
  homeUsers = ["alice"];
};
```

Set `existingPartitions` instead of `diskId` when adopting partitions that must not be repartitioned. Keep service state in `persistDirectories`, `persistFiles`, or named `volumes` whenever impermanence is enabled.

## Invariants

- `diskId` and `existingPartitions` describe mutually exclusive provisioning modes.
- Enabling impermanence requires every durable service path to be declared explicitly.
- Changing the backend or disk layout is a storage migration, not a routine configuration switch.

## Recovery

Boot a NixOS installer, unlock encrypted devices manually, and import or mount the configured backend before attempting repair. Verify persistent paths and datasets before switching the configuration; never run the installation workflow against a disk containing data that has not been backed up.
