# nix-config

Repository layout:

- `hosts/` machine-specific NixOS configs (`hosts/<host>/configuration.nix` and optional `hardware-configuration.nix`)
- `modules/` composable NixOS modules (each module is a directory with `default.nix`)
- `users/` user-level NixOS and Home Manager configs

Module composition:

- `common` is the base module
- `graphical` includes `common`
- `work` includes `graphical`
- `gaming` includes `graphical`

Hosts compose modules directly in `flake.nix` (for example, `gaming` implies `graphical` and `common`).

Deploy config changes to a remote NixOS host:

```bash
nixos-rebuild switch --flake .#nixos --target-host pbovbel@nixos --use-remote-sudo
```

Run CI-equivalent host build checks locally before commit/PR:

```bash
export NIX_SSHOPTS="-i $HOME/.ssh/id_rsa"
hosts=$(nix eval --json .#nixosConfigurations --apply builtins.attrNames | jq -r '.[]')
for host in $hosts; do
  echo "Building host: $host"
  nix build ".#nixosConfigurations.${host}.config.system.build.toplevel"
done
```
