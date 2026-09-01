# Install A Host

This runbook bootstraps a clean NixOS host with `nixos-anywhere` and the repository's disko configuration.

> [!WARNING]
> The installation phases repartition the target disk and destroy existing data. Confirm the host, target address, and disk configuration before running them. The procedure also changes the host's agenix recipient, so encrypted secrets must be rekeyed before installation.

## Prerequisites

- The host exists under `hosts/<host>/` and is registered in `flake.nix`.
- The target has booted into a NixOS live installer with network access.
- The deploy machine has this repository checked out and can reach the target over SSH.
- The target disk layout in the host configuration has been reviewed.

## Bootstrap

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

Generate the host identity in the persistent path expected by agenix:

```bash
host_key_name="${host_name//-/_}"
tmpdir="$(mktemp -d)"
mkdir -p "$tmpdir/persist/etc/agenix"
age-keygen -o "$tmpdir/persist/etc/agenix/host.agekey"
chmod 755 -R "$tmpdir/persist"
chmod 600 "$tmpdir/persist/etc/agenix/host.agekey"
```

Update the matching host key declaration in `secrets.nix`, then rekey all affected secrets:

```bash
sed -i "s|^  ${host_key_name} = \".*\";|  ${host_key_name} = \"$(age-keygen -y "$tmpdir/persist/etc/agenix/host.agekey")\";|" secrets.nix
agenix -r
```

Review the `secrets.nix` change and verify the configuration before modifying the target disk:

```bash
just check
just dry-run "$host_name"
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

Remove the temporary copy of the private host key after the installation completes:

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
