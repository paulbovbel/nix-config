# white-tower storage notes

## LUKS TPM2 + fallback passphrase enrollment

This host is configured for hybrid LUKS unlock:

- TPM2 auto-unlock via `crypttab` option `tpm2-device=auto`
- fallback interactive passphrase prompt if TPM2 unlock fails

The Nix config declares unlock behavior, but TPM2 enrollment itself is an on-disk LUKS metadata operation and must be done once on the host.

### Identify and verify the LUKS device

```bash
lsblk -f
cryptsetup luksDump /dev/disk/by-partlabel/disk-main-encrypted
```

### Enroll TPM2 token (keeps existing passphrase)

```bash
sudo systemd-cryptenroll --tpm2-device=auto /dev/disk/by-partlabel/disk-main-encrypted
```

### Verify TPM2 token is present

```bash
sudo systemd-cryptenroll /dev/disk/by-partlabel/disk-main-encrypted
```

Look for a `tpm2` token/keyslot in the output.

### Remove TPM2 token (rollback)

First list slots/tokens:

```bash
sudo systemd-cryptenroll /dev/disk/by-partlabel/disk-main-encrypted
```

Then wipe the TPM2 slot/token (replace `<slot>` with the TPM2 slot id):

```bash
sudo systemd-cryptenroll --wipe-slot=<slot> /dev/disk/by-partlabel/disk-main-encrypted
```

### Safety guidance

- Confirm passphrase unlock works before and after enrollment.
- Keep at least one known-good passphrase slot.
- Make sure firmware/TPM state is stable before relying on TPM-only unlock.
