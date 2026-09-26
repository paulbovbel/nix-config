# Install a Host

This runbook defines and installs a clean NixOS host with `nixos-anywhere` and the repository's Disko configuration.

For a self-contained, host-selectable USB installer, see [Offline USB Installer](../installer/README.md).

## Safety Warning

> **Warning:** The installation phases repartition the target disk and destroy existing data. Confirm the host, target address, and disk configuration before running them. The procedure also changes the host's agenix recipient, so encrypted secrets must be rekeyed before installation.

## Define the Host

1. Create `hosts/<host>/default.nix` with its target system, users, and profile selections.
2. Create `hosts/<host>/configuration.nix` and `hosts/<host>/hardware-configuration.nix`.
3. Register the host in the `hosts` attribute set in `flake.nix`.
4. Configure and review its stable disk identifier or existing partition paths through `rootFs`.

The host's agenix recipient is added after generating its identity below.

## Requirements

- The target has booted into a NixOS live installer with network access.
- The deploy machine has this repository checked out and can reach the target over SSH.
- Existing data on the target disk has been backed up.
- The target disk layout in the host configuration has been reviewed.

## Prepare the Installer

Set a temporary root password from the live installer:

```bash
sudo passwd
```

On the deploy machine, enter the repository development shell and set the target values:

```bash
nix develop

host_name="<host>"
target_host="root@<host-ip-or-dns>"
```

Confirm SSH access before proceeding:

```bash
ssh "$target_host" true
```

## Generate the Host Identity

Generate the host identity in the persistent path expected by agenix:

```bash
tmpdir="$(mktemp -d)"
mkdir -p "$tmpdir/persist/etc/agenix"
age-keygen -o "$tmpdir/persist/etc/agenix/host.agekey"
chmod 755 -R "$tmpdir/persist"
chmod 600 "$tmpdir/persist/etc/agenix/host.agekey"
```

Update the host's public age recipient, then rekey all affected secrets:

```bash
host_definition="hosts/$host_name/default.nix"
sed -i "s|^  ageRecipient = \".*\";|  ageRecipient = \"$(age-keygen -y "$tmpdir/persist/etc/agenix/host.agekey")\";|" "$host_definition"
agenix -r
```

## Validate the Configuration

Review the host recipient and rekeyed secrets, then verify the configuration before modifying the target disk:

```bash
git diff -- "$host_definition" secrets
just check
just dry-run "$host_name"
```

## Prepare the Nix Daemon

Prepare the live installer's Nix daemon for a remote build. This temporarily allows generated, unsigned store paths such as Home Manager activation scripts to be imported; the installed system restores signature checking:

```bash
ssh "$target_host" '
  cp --dereference /etc/nix/nix.conf /tmp/nix.conf
  printf "\nrequire-sigs = false\n" >> /tmp/nix.conf
  mount --bind /tmp/nix.conf /etc/nix/nix.conf
  systemctl restart nix-daemon
  nix --extra-experimental-features nix-command config show require-sigs
'
```

Verify that the command prints `false`.

## Install NixOS

Run the destructive installation. The explicit substituters allow installation when the private cache is unavailable:

```bash
NIX_CONFIG=$'substituters = https://cache.nixos.org https://nix-community.cachix.org' \
nix run github:nix-community/nixos-anywhere -- \
  --build-on remote \
  --no-use-machine-substituters \
  --debug -L --show-trace \
  --option substituters "https://cache.nixos.org https://nix-community.cachix.org" \
  --flake .#"$host_name" \
  --phases disko,install,reboot \
  --extra-files "$tmpdir" \
  "$target_host"
```

Remove the temporary copy of the private host key after the installation completes:

```bash
rm -rf "$tmpdir"
```

## Verify the Installation

After the target reboots, verify its configuration revision and failed units:

```bash
ssh "$target_host" 'nixos-version --configuration-revision; systemctl --failed'
```

Confirm that `/etc/agenix/host.agekey` exists and that the filesystems or datasets declared by `rootFs` are mounted. Then verify a normal deployment from the repository:

```bash
just dry-run "$host_name"
just switch "$host_name"
```

## Enroll TPM2

For a host with `rootFs.encrypted = true`, boot the installed system once and inspect the encrypted partition before enrolling TPM2 auto-unlock:

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

## Recovery and Troubleshooting

- If evaluation fails, fix `hosts/<host>/`, `secrets.nix`, or recipient declarations before running `nixos-anywhere`; do not bypass `just check`.
- If the installer cannot import store paths, confirm that `nix config show require-sigs` reports `false` in the live installer and that `nix-daemon.service` restarted successfully.
- If Disko selects an unexpected device, stop before installation and correct the stable disk identifier or explicit partition paths in `rootFs`.
- If agenix fails after reboot, verify `/etc/agenix/host.agekey`, the matching recipient in `secrets.nix`, and that secrets were rekeyed with `agenix -r`.
- If the installed system does not boot, use the live installer to unlock encrypted devices and mount or import the configured `rootFs` backend before repairing the system profile.
