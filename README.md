# nix-config

Personal NixOS fleet configuration for desktops, a laptop, and a media server. The flake composes machine-specific settings, reusable NixOS modules, Home Manager profiles, encrypted secrets, and persistent state into one configuration per host.

## Quick Start

Enter the development shell before running repository commands:

```bash
nix develop
just check
just docs
just dry-run <host>
just switch <host>
```

`just switch` activates locally when `<host>` matches the current hostname; otherwise it builds and activates through SSH. `just docs` builds the standalone module reference and prints its Nix store path. Open it with `xdg-open "$(just docs)/index.html"`; pushes to `main` publish the same site to [GitHub Pages](https://paulbovbel.github.io/nix-config/).

## Fleet

| Host | Purpose | Users and profiles |
| --- | --- | --- |
| `white-tower` | Primary desktop | `pbovbel: gaming`, `rbovbel: graphical`, `abovbel: gaming` |
| `rainbow-wave` | Kids gaming desktop | `pbovbel: gaming`, `abovbel: gaming` |
| `pbovbel-dell` | Work laptop | `pbovbel: work` |
| `becmac-pro` | Personal laptop | `pbovbel: graphical`, `rbovbel: graphical` |
| `media` | Media, game, cache, ingress, and storage server | `pbovbel: headless` |

Hosts are registered in `flake.nix`. Each `hosts/<host>/default.nix` declares its target system, public age recipient, and selected users and profiles, while `hosts/<host>/configuration.nix` contains machine settings and enables host-facing modules. Settings shared by the local site, including DNS domains, live in `hosts/site.nix`.

## Architecture

Configuration is assembled from host definitions, user-selected profiles, and globally imported reusable modules:

```text
flake.nix
├── hosts/<host>/default.nix          target system, users, and profiles
├── hosts/<host>/configuration.nix    machine policy and module enablement
├── profiles/default.nix              user-specific profile mapping
└── modules/                          reusable NixOS modules
```

Each profile entry in `profiles/default.nix` explicitly selects `homeModules` and `systemModules` for a user. Profile modules may import shared layers such as `common` or `graphical`; profile names are therefore user-specific selections rather than a global catalog.

Modules under `modules/` are imported globally and generally expose an option namespace that a host enables or configures. Their `options.nix` files are the authoritative API. Major abstractions include:

- `rootFs` for ZFS or Btrfs root layouts, encryption, impermanence, snapshots, and persistent state
- `podmanServer` for container, path, and derived environment-file declarations
- `storage` for shared ZFS datasets and generated paths
- `caddy` for public and authenticated HTTP ingress
- `backup` for scheduled pushes to remote targets
- `mediaServer`, `gameServer`, and `atticCache` for server workloads

The default package set is the pinned release nixpkgs. A host can intentionally select the pinned unstable package set with `useUnstablePackages`; modules and profiles can also receive `unstablePkgs` for localized use. Home Manager is evaluated as part of each NixOS configuration, and secrets are managed with agenix.

## Development

The documentation site is built independently of any host configuration. Each module declares its display name and summary through the internal `moduleDocumentation` option in `modules/<name>/default.nix`; modules are listed alphabetically. The documentation evaluation rejects missing or stale metadata.

Public options should provide descriptions and representative examples in the module's `options.nix`. Add `modules/<name>/README.md` when a module also needs usage guidance, invariants, or operational procedures. Module READMEs remain standalone documents with an H1 title; the site generator places their content under the page's Introduction section.

The generated site and its internal links are built as part of `just check`.

Run the full validation suite after every configuration change:

```bash
just check
just dry-run <host>
```

## Repository Layout

- Machine-specific policy, settings, and module enablement: `hosts/<host>/configuration.nix`
- Physical hardware facts and enablement, including device modules, disk identities, GPU support, firmware, and host platform: `hosts/<host>/hardware-configuration.nix`
- Host user and profile selection: `hosts/<host>/default.nix`
- Shared site values: `hosts/site.nix`
- Reusable NixOS behavior and public options: `modules/<name>/`
- User and system profile behavior: `profiles/<profile>/`
- Profile selection mapping: `profiles/default.nix`
- Agenix-encrypted values: `secrets/`
- Agenix recipient declarations: `secrets.nix`

Keep intentional machine policy in `configuration.nix`, including bootloader and kernel selection, network identity and behavior, services, and `rootFs` behavior. Keep generated or hardware-bound values in `hardware-configuration.nix`; these files may be maintained manually after their initial generation.

Do not add plaintext secrets. Stateful services on impermanent hosts must declare their persistent files or directories through `rootFs`. Server containers should use the `podmanServer` abstractions, HTTP exposure should use `caddy.sites`, and shared data should use `storage.datasets` rather than unmanaged paths.

## Runbooks

- [Define and install a host](hosts/install.md)
- [Build an offline USB installer](installer/README.md)
- [Manage Grafana dashboards](monitoring/README.md)
- [Caddy site and endpoint declarations](modules/caddy/README.md)
- [Attic cache initialization](modules/attic-cache/README.md)
