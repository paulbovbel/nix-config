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

Run the full local check suite before commit/PR:

```bash
just all
```

`just all` runs:

- `just nix-lint` (`statix check .`, `deadnix .`, `alejandra .`)
- `just python-lint` (`ruff check` and `ruff format --check`)
- `just shell-lint` (`shellcheck` and `shfmt -d` for `*.sh` files)
- `just nix-dry` (`nix flake check` and `nixos-rebuild dry-run --flake .#white-tower`)
