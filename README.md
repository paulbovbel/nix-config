# nix-config

Personal NixOS configuration for desktops, laptops, and a media server.

## Quick Start

Enter the development shell before running repository commands:

```bash
nix develop
just check
just docs
just dry-run <host>
just switch <host>
```

`just switch` activates locally or through SSH, depending on the host. `just docs` prints the path to the [module reference](https://paulbovbel.github.io/nix-config/); open it with `xdg-open "$(just docs)/index.html"`.

## Fleet

| Host | Purpose | Users and profiles |
| --- | --- | --- |
| `white-tower` | Primary desktop | `pbovbel: gaming`, `rbovbel: graphical`, `abovbel: gaming` |
| `rainbow-wave` | Kids gaming desktop | `pbovbel: gaming`, `abovbel: gaming` |
| `pbovbel-dell` | Work laptop | `pbovbel: work` |
| `becmac-pro` | Personal laptop | `pbovbel: graphical`, `rbovbel: graphical` |
| `media` | Media, game, cache, ingress, and storage server | `pbovbel: headless` |

## Architecture

Hosts are registered in `flake.nix`. Each `hosts/<host>/default.nix` selects a system, age recipient, users, and profiles. `profiles/default.nix` maps those user-specific profiles to Home Manager and system modules. Reusable modules under `modules/` are imported globally and enabled from host configurations.

Key abstractions (see each module's `options.nix` for its API):

- `rootFs` for ZFS or Btrfs root layouts, encryption, impermanence, snapshots, and persistent state
- `podmanServer` for container, path, and derived environment-file declarations
- `storage` for shared ZFS datasets and generated paths
- `caddy` for public and authenticated HTTP ingress
- `backup` for scheduled pushes to remote targets
- `mediaServer`, `gameServer`, and `atticCache` for server workloads

Hosts use pinned release nixpkgs by default; `useUnstablePackages` selects unstable for a host, while `unstablePkgs` supports localized use. Home Manager is evaluated with NixOS; agenix manages secrets.

## Development

Describe public options in `modules/<name>/options.nix`; use a module README for usage, invariants, or operations. Add display metadata in `modules/<name>/default.nix` for the generated documentation site. Keep non-Nix scripts in `modules/<name>/scripts/` and tests, including NixOS VM tests and test helpers, in `modules/<name>/tests/`. CI validates the site and its links with `just nix-test`.

## Repository Layout

- Machine policy and module enablement: `hosts/<host>/configuration.nix`
- Hardware facts and device identities: `hosts/<host>/hardware-configuration.nix`
- Host user and profile selection: `hosts/<host>/default.nix`
- Shared site values: `hosts/site.nix`
- Reusable NixOS behavior and public options: `modules/<name>/`
- Module scripts, tests, and static assets: `modules/<name>/{scripts,tests,assets}/`
- Composite-module scripts and tests: `modules/<name>/<submodule>/{scripts,tests}/`
- Profile-only Home Manager scripts: `profiles/<profile>/home/scripts/`
- Documentation builder and templates: `modules/documentation/`
- Deployment tooling and runbooks: `modules/deployment/`
- Monitoring services and Grafana dashboards: `modules/monitor/`
- User and system profile behavior: `profiles/<profile>/`
- Profile selection mapping: `profiles/default.nix`
- Agenix-encrypted values: `secrets/`
- Agenix recipient declarations: `agenix-rules.nix`

Keep machine policy in `configuration.nix` and hardware-bound values in `hardware-configuration.nix`. Never commit plaintext secrets; declare persistent state with `rootFs` and use `podmanServer`, `caddy`, and `storage` for server workloads.

## Runbooks

- [Install and deploy a host remotely](modules/deployment/remote/README.md)
- [Build an offline USB installer](modules/deployment/usb/README.md)
- [Manage Grafana dashboards](modules/monitor/README.md)
- [Caddy site and endpoint declarations](modules/caddy/README.md)
- [Attic cache initialization](modules/attic-cache/README.md)
