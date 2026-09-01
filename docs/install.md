# Install A Host

This runbook bootstraps a clean NixOS host with a host-specific USB image or, alternatively, `nixos-anywhere`. Both methods use the repository's disko configuration.

> [!WARNING]
> The installation phases repartition the target disk and destroy existing data. Confirm the host, target address, and disk configuration before running them. The procedure also changes the host's agenix recipient, so encrypted secrets must be rekeyed before installation.

## Prerequisites

- The host exists under `hosts/<host>/` and is registered in `flake.nix`.
- The build machine has this repository checked out.
- The target disk layout in the host configuration has been reviewed.

## USB Installer

Set the target host, identify the whole USB device, and run the installer creator. The output device must be the USB drive, not one of its partitions. The creator verifies the device and unmounts its mounted filesystems before building:

```bash
host_name="<host>"
lsblk
nix run .#create-installer -- "$host_name" /dev/<usb-device>
```

To reuse an existing host identity, supply either a local key path or an SCP source as the final argument:

```bash
nix run .#create-installer -- \
  "$host_name" \
  /dev/<usb-device> \
  root@<existing-host>:/persist/etc/agenix/host.agekey
```

If a previous creation attempt failed after building the image, rerun it with the retained key and ISO paths printed or retained by that attempt. Supplying the ISO as the fourth argument skips the image build entirely:

```bash
nix run .#create-installer -- \
  "$host_name" \
  /dev/<usb-device> \
  /tmp/<retained-directory>/host.agekey \
  /tmp/<retained-directory>/result/iso/nixos-${host_name}-installer.iso
```

Only reuse an ISO with the host key from the same creation attempt. When the key already matches `secrets.nix`, the creator also preserves the existing ciphertext.

The creator performs these steps before touching the USB:

- Generates a new host age identity, unless an existing identity was supplied.
- Updates the matching recipient in `secrets.nix`.
- Re-encrypts affected secrets with `agenix -r`.
- Builds the host-specific installer containing the complete system closure.

After explicit confirmation, it flashes the image and adds a `NIXOS_KEYS` partition containing `host.agekey`. Review and commit the resulting `secrets.nix` and encrypted secret changes.

Boot the target from that USB. The installer starts automatically on `tty1`, mounts the `NIXOS_KEYS` partition, and prints the configured target disk identity. It requires the host name to be typed before it partitions the disk. Other virtual consoles remain available if troubleshooting is needed. Remove the USB and reboot when installation completes.

> [!IMPORTANT]
> The installer USB contains the host's unencrypted private age identity. Securely erase or physically secure the USB after installation. If installer creation fails after rekeying, the command prints the temporary path where it retained the new host key.

## Remote Installer

The USB installer is preferred when the target is physically accessible. To install remotely instead, boot the target into a NixOS live installer with network access, set a temporary root password, and configure its address:

```bash
sudo passwd
host_name="<host>"
target_host="root@<host-ip-or-dns>"
```

Generate a new host identity in the persistent path expected by agenix, update its recipient in `secrets.nix`, and rekey affected secrets:

```bash
host_key_name="${host_name//-/_}"
tmpdir="$(mktemp -d)"
mkdir -p "$tmpdir/persist/etc/agenix"
age-keygen -o "$tmpdir/persist/etc/agenix/host.agekey"
chmod 755 -R "$tmpdir/persist"
chmod 600 "$tmpdir/persist/etc/agenix/host.agekey"
sed -i "s|^  ${host_key_name} = \".*\";|  ${host_key_name} = \"$(age-keygen -y "$tmpdir/persist/etc/agenix/host.agekey")\";|" secrets.nix
agenix -r
```

Run the destructive installation. The explicit substituters allow installation when the private cache is unavailable:

```bash
NIX_CONFIG=$'substituters = https://cache.nixos.org https://nix-community.cachix.org https://cuda-maintainers.cachix.org' \
nix run github:nix-community/nixos-anywhere -- \
  --build-on local \
  --no-use-machine-substituters \
  --debug -L --show-trace \
  --option substituters "https://cache.nixos.org https://nix-community.cachix.org https://cuda-maintainers.cachix.org" \
  --flake .#"$host_name" \
  --phases disko,install,reboot \
  --extra-files "$tmpdir" \
  "$target_host"
```

Remove the temporary copy of the private host key after the remote installation completes:

```bash
rm -rf "$tmpdir"
```

## TPM2 Enrollment

For a host with `rootZfs.encrypted = true`, boot the installed system once and inspect the encrypted partition before enrolling TPM2 auto-unlock:

```bash
lsblk -f
cryptsetup luksDump /dev/disk/by-partlabel/disk-main-encrypted
sudo systemd-cryptenroll --tpm2-device=auto /dev/disk/by-partlabel/disk-main-encrypted
```

Add a recovery passphrase after enrollment if the installation does not already have one:

```bash
sudo systemd-cryptenroll /dev/disk/by-partlabel/disk-main-encrypted
```

Verify that both the TPM2 token and a recovery method are present before rebooting.
