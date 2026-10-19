# USB Deployment

Build a host-specific USB installer for offline installation. The selected host determines the disk layout, boot media, and encrypted agenix identity.

## Platforms

- `white-tower`, `rainbow-wave`, `pbovbel-dell`, and `media` use the standard x86_64 NixOS installer. Their configured `rootFs.diskId` is repartitioned by Disko.
- `becmac-pro` uses the Asahi Apple Silicon installer. It reuses the EFI, root, and swap partitions in its current host configuration and does not modify the Apple partition table.

Build on the target architecture or use a compatible remote builder or binfmt setup. Apple Silicon builds temporarily copy the root-only `/boot/vendorfw` using `sudo`.

## Safety

The installer destroys storage selected by the target host configuration. Back up all required data before using it.

Before running Disko, every image:

- verifies that its configured disk or partitions exist
- verifies that the target disk is not the installer USB
- decrypts the embedded host identity and verifies its public recipient
- requires the exact confirmation `ERASE <host>`

The Apple Silicon installer also verifies its EFI partition against the device tree. Damage to Apple partition tables, recovery partitions, or Asahi UEFI can require a DFU restore.

## Build The ISO

Enter the development shell and list available hosts:

```bash
nix develop
just deploy hosts
```

ISO creation has two host-key modes.

### Reuse The Current Key

Use `reuse` when creating an installer for the machine running the build:

```bash
just installer key becmac-pro reuse
```

The selected host must match `hostname`. The script verifies the public recipient of `/persist/etc/agenix/host.agekey` and encrypts the key for the installer. It does not change recipients or rekey secrets.

### Create A New Key

Use `new` when the selected host is unavailable or should receive a replacement identity:

```bash
just installer key white-tower new
```

After confirmation with `ROTATE <host>`, the script generates a new host key, updates `ageRecipient`, and rekeys affected secrets with `agenix -r`. Temporary unencrypted keys are removed after preparation.

Review and commit the host recipient and rekeyed secrets before erasing the target. Encrypted installer payloads stay in the ignored `secrets/installer/` directory:

```bash
git diff -- hosts/<host>/default.nix secrets
git status --short
```

Do not deploy the rekeyed configuration to the old installation because its old identity no longer matches the new recipient.

Both modes prompt for a passphrase to unlock the encrypted installer payloads. After reviewing and committing preparation changes, build the ISO:

```bash
just installer iso white-tower -L
```

The ISO is built under `result-installer-<host>/iso/`. Build retries reuse the prepared payloads without rotating keys or changing the passphrase. Private keys are never copied into the Nix store in plaintext.

### Migrate Application And System State

For the current host, capture encrypted homes and selected `/persist` paths explicitly, then pass the archive to the build:

```bash
just installer state white-tower /tmp/white-tower-state.tar.zst.age --close-apps
just installer iso white-tower --state /tmp/white-tower-state.tar.zst.age -L
```

Omit `--close-apps` to leave applications running. It stops graphical application scopes, but not the build terminal, session services, or system services. Capture fails if files change while `tar` reads them. Recreate the archive if you prepare a different installer identity.

The archive preserves ownership, permissions, ACLs, extended attributes, and sparse files. It excludes personal XDG directories, `.cache`, Trash, and Flatpak caches; other application state remains included.

Persisted state includes UID/GID allocation, machine ID, SSH host keys, NetworkManager and Tailscale identity, Bluetooth pairings, CUPS, system Flatpaks, and GDM. Logs, caches, and the separately handled agenix host key are excluded.

The compressed archive is encrypted without writing a plaintext copy. The installer extracts it after Disko prepares the target filesystems. Keep a separate backup.

## Automatic Upgrades

The installer records the Git revision and branch so enabled hosts can verify update ancestry. A dirty build disables automatic upgrades until a clean configuration is activated.

Automatic upgrades are currently enabled for `white-tower`, `rainbow-wave`, and `media`. They are disabled by host configuration for `pbovbel-dell` and `becmac-pro`.

Upgrades require access to GitHub and configured binary caches.

## Write The USB

To select from connected whole USB disks interactively:

```bash
just installer write result-installer-<host>/iso/nixos-<host>-offline-installer-*.iso
```

Alternatively, locate the whole USB device by its stable ID and provide it explicitly:

```bash
ls -l /dev/disk/by-id/usb-*
```

Write the installer image:

```bash
just installer write \
  result-installer-<host>/iso/nixos-<host>-offline-installer-*.iso \
  /dev/disk/by-id/usb-<device>
```

The writer rejects partitions, non-USB paths, mounted devices, active swap, and root filesystem disks. It requires `WRITE` before invoking `dd`.

## Boot And Install

1. Shut down the target and connect the USB drive.
2. Boot the USB through the machine's UEFI environment.
3. On Apple Silicon, use the existing Asahi U-Boot environment and select the USB entry from `bootmenu` if it does not boot automatically.
4. Wait for the root autologin to start the installer on tty1.
5. Enter the passphrase protecting the installer payloads.
6. Review the displayed target disk or partitions.
7. Type `ERASE <host>` exactly.
8. Wait for Disko and `nixos-install` to finish.
9. Remove the USB drive and press Enter to reboot.

The installer installs the decrypted identity at `/persist/etc/agenix/host.agekey` before activation.

## Recovery

If identity decryption, recipient validation, or storage validation fails, no disk changes have occurred. Correct the problem and reboot the installer.

If installation fails after Disko starts, leave the USB connected, reboot into it, and repeat the installation. Disko and `nixos-install` recreate the configured filesystems and installation.

If the installer is cancelled or exits with an error, tty1 falls back to an interactive root shell for inspection and recovery.

The Apple Silicon image does not create the Asahi stub, EFI partition, or UEFI environment. If those are missing or damaged, repair them from macOS using the upstream Asahi installer before retrying.

## Remote Alternative

For a networked installation driven by another machine, use the existing `nixos-anywhere` procedure in [Remote Deployment](../remote/README.md). That path is preferable when the target can be reached over SSH and does not need a self-contained offline image.
