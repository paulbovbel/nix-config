# nix-config

Repository layout:

- `hosts/` machine-specific NixOS configs (`hosts/<host>/configuration.nix` and optional `hardware-configuration.nix`)
- `modules/` composable NixOS modules (each module is a directory with `default.nix`)
- `users/` user-level NixOS and Home Manager configs (`users/<user>.nix` plus per-profile modules under `users/<user>/`)
- `secrets/` agenix-encrypted secrets (`secrets/laptop/`, `secrets/server/`)
- `secrets.nix` agenix public key declarations
- `assets/` static assets (wallpapers, etc.)

Module composition:

- `common` is the base module
- `graphical` includes `common`, for workstations
- `work` includes `graphical`
- `gaming` includes `graphical`
- `server` includes `common`, for headless setups
- `llama-cpp` includes `common`, runs an LLM server proxy

Hosts compose modules directly in `flake.nix` (for example, `gaming` implies `graphical` and `common`).

User profiles are selected in `flake.nix` and map to modules under each user directory:

- `users/pbovbel/{headless,graphical,work,gaming}.nix`
- `users/rbovbel/graphical.nix`
- Shared user Home Manager modules are in `users/common/{base,graphical,gravatar}.nix`

Install baseline config on a remote host booted into live-installer:

```bash
nix run github:numtide/nixos-anywhere -- --debug --flake .#white-tower root@192.168.1.16 ; echo $?
```

Clean-install bootstrap for login-critical password hash files:

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

Deploy config changes to a remote NixOS host:

```bash
nixos-rebuild switch --flake .#white-tower --target-host deploy@white-tower  --build-host deploy@white-tower --use-remote-sudo
```

Run the full local check suite before commit/PR:

```bash
just all
```

`just all` runs:

- `just nix-lint` (`statix check .`, `deadnix .`, `alejandra .`)
- `just python-lint` (`ruff check` and `ruff format --check`)
- `just shell-lint` (`shellcheck` and `shfmt -d` for `*.sh` files)
- `just nix-dry` (`nix flake check` and `nixos-rebuild dry-run --flake .#white-tower`)
