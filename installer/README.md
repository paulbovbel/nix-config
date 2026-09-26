# Offline USB Installer

This directory builds a self-contained USB installer for any host registered in `flake.nix`. The selected host determines the target system, Disko layout, boot media, and encrypted agenix identity. Installation does not require network access.

## Platforms

- `white-tower`, `rainbow-wave`, `pbovbel-dell`, and `media` use the standard x86_64 NixOS installer. Their configured `rootFs.diskId` is repartitioned by Disko.
- `becmac-pro` uses the Asahi Apple Silicon installer. It reuses the EFI, root, and swap partitions in its current host configuration and does not modify the Apple partition table.

The image must be built on the target architecture or on a machine with a compatible remote builder or binfmt setup. In particular, building an x86_64 image from `becmac-pro` requires an x86_64 builder. For Apple Silicon images, the build script uses `sudo` to copy the target's root-only `/boot/vendorfw` into a temporary user-readable directory, removes that copy on exit, and runs Nix evaluation unprivileged.

## Safety

The installer destroys storage selected by the target host configuration. Back up all required data before using it.

Before running Disko, every image:

- verifies that its configured disk or partitions exist
- verifies that the target disk is not the installer USB
- decrypts the embedded host identity and verifies its public recipient
- requires the exact confirmation `ERASE <host>`

The Apple Silicon variant additionally verifies that the configured EFI partition matches the Asahi EFI partition published by the device tree. Damage to Apple Silicon partition tables, recovery partitions, or the Asahi UEFI environment can require a DFU restore.

## Build The ISO

Enter the development shell and list available hosts:

```bash
nix develop
nix eval --json .#lib.hostNames
```

The selected commit and branch are recorded in the installed generation so the guarded automatic upgrader can verify ancestry. Building from a dirty working tree is allowed, but the installer records a dirty revision and automatic upgrades remain disabled until a clean configuration is activated. In `new` mode, commit the generated recipient and rekeyed secrets after the ISO build and before installation; that commit will descend from the revision embedded in a clean build.

ISO creation has two host-key modes.

### Reuse The Current Key

Use `reuse` when creating an installer for the machine running the build:

```bash
just installer-iso becmac-pro reuse -L
```

The selected host must match `hostname`. This mode:

1. Reads `/persist/etc/agenix/host.agekey` through `sudo` into a private temporary directory.
2. Confirms that its public recipient matches `hosts/becmac-pro/default.nix`.
3. Encrypts it to a temporary installer recipient as `secrets/installer/<host>-host.agekey.age`.
4. Protects the temporary installer identity with the supplied passphrase.
5. Builds the ISO with both encrypted payloads.
6. Deletes the unencrypted temporary identities.

This mode does not change recipients or rekey secrets.

### Create A New Key

Use `new` when the selected host is unavailable or should receive a replacement identity:

```bash
just installer-iso white-tower new -L
```

This mode requires typing `ROTATE <host>`, then:

1. Generates a new host identity and temporary installer identity in a private temporary directory.
2. Encrypts the host identity to the temporary installer recipient.
3. Protects the temporary installer identity with the supplied passphrase.
4. Updates `ageRecipient` in the selected host's `default.nix`.
5. Runs `agenix -r` to rekey affected secrets.
6. Builds the ISO with the encrypted payloads.
7. Deletes the unencrypted temporary identities.

Review and commit the recipient, encrypted installer identity, and rekeyed secrets before erasing the target:

```bash
git diff -- hosts/<host>/default.nix secrets
git status --short
```

Do not deploy the rekeyed configuration to the old installation because its old identity no longer matches the new recipient.

Both modes prompt once for a strong passphrase protecting a temporary installer identity. The host identity and optional home archive are encrypted to that temporary identity, so the same passphrase unlocks every installer payload. The resulting ISO is under `result/iso/` and contains the complete selected system closure. Private identities are never copied into the Nix store in plaintext. After a successful build, the script offers to select and write a connected USB disk.

### Migrate Home Application State

When the selected host matches the running hostname, the build can embed an encrypted archive of its configured users' home directories. It optionally stops running systemd graphical application scopes before capture while preserving the scope containing the build terminal. GNOME Shell, GNOME session services, and the display manager are not stopped. Applications outside systemd application scopes may remain active, and the build fails if files change while `tar` reads them.

The archive preserves ownership, permissions, ACLs, extended attributes, and sparse files. It excludes personal XDG directories (`Desktop`, `Documents`, `Downloads`, `Music`, `Pictures`, `Public`, `Templates`, and `Videos`) plus `.cache`, `.local/share/Trash`, and Flatpak application cache directories. Other application state, including XDG, Flatpak, and non-XDG hidden directories, remains included.

The archive is compressed and streamed directly into encryption for the temporary installer recipient; no plaintext archive is written to disk or copied into the Nix store. During installation, the passphrase entered to unlock the host identity also unlocks the archive, which is extracted into the mounted target homes after Disko prepares the filesystems. This supports migrations between filesystem backends, but it is not a replacement for a separate backup.

## Automatic Upgrades

The installer records the Git revision and branch used to build the target closure. Hosts with `autoUpgrade.enable = true` can therefore clone the repository, verify that an update descends from a clean installed revision, and activate it normally after installation. A dirty installer build is marked as such, and automatic upgrades refuse it to avoid a possible rollback.

Automatic upgrades are currently enabled for `white-tower`, `rainbow-wave`, and `media`. They are disabled by host configuration for `pbovbel-dell` and `becmac-pro`.

The installed host identity decrypts the repository SSH key used by the upgrade service. Upgrades still require network access to GitHub and any configured binary caches, even though initial installation is offline.

## Write The USB

To select from connected whole USB disks interactively:

```bash
just installer-write result/iso/nixos-<host>-offline-installer-*.iso
```

Alternatively, locate the whole USB device by its stable ID and provide it explicitly:

```bash
ls -l /dev/disk/by-id/usb-*
```

Write the installer image:

```bash
just installer-write \
  result/iso/nixos-<host>-offline-installer-*.iso \
  /dev/disk/by-id/usb-<device>
```

The writer rejects partitions, non-USB paths, mounted devices, active swap, and any disk backing the current root filesystem, including ZFS pool members. It displays the selected disk and requires typing `WRITE` before invoking `dd`.

## Boot And Install

1. Shut down the target and connect the USB drive.
2. Boot the USB through the machine's UEFI environment.
3. On Apple Silicon, use the existing Asahi U-Boot environment and select the USB entry from `bootmenu` if it does not boot automatically.
4. Wait for the installer prompt on tty1.
5. Enter the passphrase protecting the installer payloads.
6. Review the displayed target disk or partitions.
7. Type `ERASE <host>` exactly.
8. Wait for Disko and `nixos-install` to finish.
9. Remove the USB drive and press Enter to reboot.

The installer copies the decrypted identity to `/persist/etc/agenix/host.agekey` with mode `0600` before activating the installed configuration.

## Recovery

If identity decryption, recipient validation, or storage validation fails, no disk changes have occurred. Correct the problem and reboot the installer.

If installation fails after Disko starts, leave the USB connected, reboot into it, and repeat the installation. Disko and `nixos-install` recreate the configured filesystems and installation.

The Apple Silicon image does not create the Asahi stub, EFI partition, or UEFI environment. If those are missing or damaged, repair them from macOS using the upstream Asahi installer before retrying.

## Remote Alternative

For a networked installation driven by another machine, use the existing `nixos-anywhere` procedure in [`hosts/install.md`](../hosts/install.md). That path is preferable when the target can be reached over SSH and does not need a self-contained offline image.
