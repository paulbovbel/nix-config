Clean-install bootstrap for white-tower:

```bash
# in live-installer environment
sudo passwd # configure a root password

# from deploy machine
tmpdir="$(mktemp -d)"
mkdir -p "$tmpdir/persist/etc/agenix"
age-keygen -o "$tmpdir/persist/etc/agenix/host.agekey"
chmod 755 -R "$tmpdir/persist"
chmod 600 "$tmpdir/persist/etc/agenix/host.agekey"

# update secrets.nix:
sed -i "s|^  whiteTower = \".*\";|  whiteTower = \"$(age-keygen -y "$tmpdir/persist/etc/agenix/host.agekey")\";|" secrets.nix
agenix -r

nix run github:numtide/nixos-anywhere -- \
  --flake .#white-tower \
  --extra-files "$tmpdir" \
  root@192.168.1.16

rm -rf "$tmpdir"
```

Post-install TPM2 auto-unlock enrollment for `white-tower` (run on the installed host after first boot):

```bash
lsblk -f
cryptsetup luksDump /dev/disk/by-partlabel/disk-main-encrypted
sudo systemd-cryptenroll --tpm2-device=auto /dev/disk/by-partlabel/disk-main-encrypted
sudo systemd-cryptenroll /dev/disk/by-partlabel/disk-main-encrypted
```

This adds TPM2-based LUKS auto-unlock while keeping passphrase fallback. See host-specific notes in `hosts/white-tower/README.md`.

Deploy config changes to a remote NixOS host:

```bash
nixos-rebuild switch --flake .#white-tower --target-host deploy@white-tower  --build-host deploy@white-tower --use-remote-sudo
```
