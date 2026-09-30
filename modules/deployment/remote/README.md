# Remote Deployment

This runbook defines and installs a clean NixOS host with `nixos-anywhere` and the repository's Disko configuration.

For offline installation, see [USB Deployment](../usb/README.md).

## Safety Warning

> **Warning:** Installation repartitions the target disk. Back up data and confirm the host, address, and disk layout. Rekey secrets after changing the agenix recipient.

## Define the Host

1. Create `hosts/<host>/default.nix` with its target system, users, and profile selections.
2. Create `hosts/<host>/configuration.nix` and `hosts/<host>/hardware-configuration.nix`.
3. Register the host in the `hosts` attribute set in `flake.nix`.
4. Configure and review its stable disk identifier or existing partition paths through `rootFs`.

The host's agenix recipient is added after generating its identity below.

## Requirements

- The target has booted into a NixOS live installer with network access.
- The deploy machine has this repository checked out and can reach the target over SSH.

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

## Connect the Installer to Tailscale

The live installer does not include Tailscale. Start it temporarily from
`nixpkgs`, then complete the interactive login using the URL printed by
`tailscale up`:

```bash
ssh -t "$target_host" '
  nix --extra-experimental-features "nix-command flakes" shell nixpkgs#tailscale --command bash -c '\''
    sudo tailscaled --state=/tmp/tailscale.state >/tmp/tailscaled.log 2>&1 &
    tailscaled_pid=$!
    trap "sudo kill $tailscaled_pid" EXIT
    sudo tailscale up
    tailscale status
    curl --fail https://nix-cache.bovbel.com/nixos/nix-cache-info
    wait
  '\''
'
```

Leave this command running for the installation. The installed system enrolls
with its agenix-managed Tailscale key after reboot, so remove the temporary
installer device from the Tailscale admin console when installation is
complete.

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

Review the recipient and rekeyed secrets before modifying the disk:

```bash
git diff -- "$host_definition" secrets
just check
just dry-run "$host_name"
```

## Prepare the Nix Daemon

Prepare the live installer's Nix daemon for a remote build. This temporarily allows generated, unsigned store paths such as Home Manager activation scripts to be imported and enables the cache now reachable over Tailscale; the installed system restores its declared Nix settings:

```bash
ssh "$target_host" '
  cp --dereference /etc/nix/nix.conf /tmp/nix.conf
  cat >> /tmp/nix.conf <<"EOF"
require-sigs = false
substituters = https://cache.nixos.org https://nix-community.cachix.org https://nix-cache.bovbel.com/nixos
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbOJTs4f2vT5M9T8qN9kYChdD4= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= nixos:H0/odUxYOFF1DaN52oWwcKlHUkXIZmrqb8QywcCYvd4=
EOF
  mount --bind /tmp/nix.conf /etc/nix/nix.conf
  systemctl restart nix-daemon
  nix --extra-experimental-features nix-command config show require-sigs
'
```

Verify that the command prints `false`.

## Install NixOS

Run the destructive installation. The target live installer uses the private cache over Tailscale and falls back to the public caches if needed:

```bash
substituters="https://cache.nixos.org https://nix-community.cachix.org https://nix-cache.bovbel.com/nixos"
trusted_public_keys="cache.nixos.org-1:6NCHdD59X431o0gWypbOJTs4f2vT5M9T8qN9kYChdD4= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= nixos:H0/odUxYOFF1DaN52oWwcKlHUkXIZmrqb8QywcCYvd4="

NIX_CONFIG="substituters = $substituters
trusted-public-keys = $trusted_public_keys" \
nix run github:nix-community/nixos-anywhere -- \
  --build-on remote \
  --debug -L --show-trace \
  --option substituters "$substituters" \
  --option trusted-public-keys "$trusted_public_keys" \
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

- If evaluation fails, fix the host configuration or recipient declarations before installing.
- If the installer cannot import store paths, confirm that `nix config show require-sigs` reports `false` in the live installer and that `nix-daemon.service` restarted successfully.
- If Disko selects an unexpected device, stop before installation and correct the stable disk identifier or explicit partition paths in `rootFs`.
- If agenix fails after reboot, verify `/etc/agenix/host.agekey`, the matching recipient in `agenix-rules.nix`, and that secrets were rekeyed with `agenix -r`.
- If the installed system does not boot, use the live installer to unlock encrypted devices and mount or import the configured `rootFs` backend before repairing the system profile.
