# nix-config

## Overview

Hosts are declared in `hosts/default.nix` with per-host `systemProfiles` and `users`; `flake.nix` imports this inventory and loads each host module from `hosts/<host>/configuration.nix` by convention.

Inventory schema in `hosts/default.nix`:

- host key: `<host>`
- `systemProfiles`: list of module profile names (optional)
- `useUnstablePackages`: use `nixpkgs-unstable` as the host-wide `pkgs` package set instead of release nixpkgs (optional, default `false`)
- `users`: list of `{ name, systemModule, profiles }`

User profiles map to modules under each user directory:

- `users/pbovbel/{headless,graphical,work,gaming}.nix`
- `users/rbovbel/graphical.nix`
- Shared user Home Manager modules are in `users/common/{base,graphical,gravatar}.nix`

Run the full local check suite before commit/PR:

```bash
just check
```

### Repository layout

- `hosts/` host inventory in `hosts/default.nix` plus machine-specific NixOS configs
- `modules/` composable NixOS modules (each module is a directory with `default.nix`)
- `users/` user-level NixOS and Home Manager configs (`users/<user>.nix` plus per-profile modules under `users/<user>/`)
- `secrets/` agenix-encrypted secrets
- `secrets.nix` agenix public key declarations
- `assets/` static assets (wallpapers, etc.)

### Module composition

- `common` is the base module
- `graphical` includes `common`, for workstations
- `work` includes `graphical`
- `gaming` includes `graphical`
- `headless` includes `common`, for headless setups
- `llama-cpp` includes `common`, runs an LLM server proxy

## Initial install

Bootstrap a clean host install:

```bash
# in live-installer environment
sudo passwd # configure a root password

# from deploy machine
host_name="<host>"
target_host="root@<host-ip-or-dns>"

host_key_name="${host_name//-/_}"
tmpdir="$(mktemp -d)"
mkdir -p "$tmpdir/persist/etc/agenix"
age-keygen -o "$tmpdir/persist/etc/agenix/host.agekey"
chmod 755 -R "$tmpdir/persist"
chmod 600 "$tmpdir/persist/etc/agenix/host.agekey"

# update secrets.nix host key (example: host_name=white-tower, host_key_name=white_tower)
sed -i "s|^  ${host_key_name} = \".*\";|  ${host_key_name} = \"$(age-keygen -y "$tmpdir/persist/etc/agenix/host.agekey")\";|" secrets.nix
agenix -r

nix run github:numtide/nixos-anywhere -- \
  --flake .#"$host_name" \
  --extra-files "$tmpdir" \
  "$target_host"

rm -rf "$tmpdir"
```

Post-install TPM2 auto-unlock enrollment (run on installed host after first boot):

```bash
lsblk -f
cryptsetup luksDump /dev/disk/by-partlabel/disk-main-encrypted
sudo systemd-cryptenroll --tpm2-device=auto /dev/disk/by-partlabel/disk-main-encrypted
sudo systemd-cryptenroll /dev/disk/by-partlabel/disk-main-encrypted
```

## Deploy updates

Switch a host to its flake configuration, runs against localhost by default:

```bash
just switch <host>
```
