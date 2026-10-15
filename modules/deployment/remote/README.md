# Remote Deployment

Install a clean NixOS host over SSH using the development shell's pinned
`nixos-anywhere` and the repository's Disko configuration. For offline installation
and Apple Silicon partition reuse, see [USB Deployment](../usb/README.md).

Installation repartitions the target disk. Review the host's stable disk ID and
back up required data before installing.

## Define the Host

1. Create `hosts/<host>/default.nix` with system, installer kind, `ciBuild`, and users.
2. Create `configuration.nix` with module enablement and `userProfiles`, and
   `hardware-configuration.nix` with hardware settings.
3. Register the host in `hosts/default.nix`.
4. Review the disk layout declared through `rootFs`.

## Prepare the Live Installer

Boot a NixOS live installer with network access and set a temporary root password:

```bash
sudo passwd
```

On the controller:

```bash
nix develop
just hosts
ssh root@<target-address> true
```

### Connect to Tailscale

If the private cache requires Tailscale, start it temporarily on the live installer
and complete interactive login using the URL printed by `tailscale up`:

```bash
ssh -t root@<target-address> '
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

Leave this connection running through installation. Remove the temporary installer
device from the Tailscale admin console afterward; the installed system enrolls
with its agenix-managed key.

## Prepare and Review the Identity

Both remote and USB installation consume the same encrypted identity payloads:

```bash
just installer-key <host> new
git diff -- hosts/<host>/default.nix secrets
just check
just build-plan <host>
```

`new` requires `ROTATE <host>`, updates the public recipient, and rekeys affected
secrets. Use `reuse` when preparing the identity on the existing target itself.
Review and commit the recipient and rekeyed secrets before installing. The
encrypted payloads remain in ignored `secrets/installer/`; retain them for retries.
Do not deploy a rotated recipient to an old installation that still uses the old key.

## Install

```bash
just install <host> root@<target-address>
```

The command checks SSH access, decrypts and validates the prepared identity,
evaluates a build plan, and requires `ERASE <host>`. It derives cache URLs and
signing keys from the selected host configuration, prepares the live Nix daemon,
and builds remotely before installing and rebooting. Branch and revision metadata
match regular deployment commands. Dirty checkouts disable automatic upgrades.

Temporary plaintext identities are removed on exit, including failures. Retrying
uses the same prepared identity; it does not rotate keys again. The live daemon's
temporary `require-sigs = false` override disappears on reboot.

## Verify

After reboot, use the installed account's SSH access:

```bash
ssh <host> 'nixos-version --configuration-revision; systemctl --failed'
just build-plan <host>
just switch <host>
```

Confirm `/persist/etc/agenix/host.agekey` exists and declared filesystems or datasets
are mounted. If needed, use `just switch <host> --target <user>@<address>`.

## Enroll TPM2

For encrypted hosts, inspect the partition before enrolling automatic unlock:

```bash
lsblk -f
cryptsetup luksDump /dev/disk/by-partlabel/disk-main-encrypted
sudo systemd-cryptenroll --tpm2-device=auto /dev/disk/by-partlabel/disk-main-encrypted
```

If a recovery passphrase is missing, add one:

```bash
sudo systemd-cryptenroll /dev/disk/by-partlabel/disk-main-encrypted
```

Verify the TPM2 token and recovery method before rebooting.

## Recovery

- Fix evaluation or recipient mismatches before retrying installation.
- For store-import failures, verify `nix config show require-sigs` reports `false`
  in the live installer and that its Nix daemon restarted.
- Correct unexpected disk selection in the host's `rootFs` configuration.
- For agenix failures, check the persisted identity and recipient, and rekey with
  `agenix -r` if needed.
- For boot failures, unlock and mount the configured filesystems from the live
  installer before repairing the system profile.
