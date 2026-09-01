# nix-config

Personal NixOS fleet configuration for desktops, a laptop, and a media server. The flake composes machine-specific settings, reusable NixOS modules, Home Manager profiles, encrypted secrets, and ZFS-backed persistent state into one configuration per host.

## Hosts

| Host | Purpose | Users and profiles |
| --- | --- | --- |
| `white-tower` | Primary gaming desktop | `pbovbel: gaming`, `rbovbel: graphical`, `abovbel: gaming` |
| `rainbow-wave` | Gaming desktop | `pbovbel: gaming`, `abovbel: gaming` |
| `pbovbel-dell` | Work laptop | `pbovbel: work` |
| `becmac-pro` | Apple silicon laptop | `pbovbel: graphical`, `rbovbel: graphical` |
| `media` | Media, game, cache, ingress, and storage server | `pbovbel: headless` |

Hosts are registered in `flake.nix`. Each `hosts/<host>/default.nix` declares its target system and selects users and their profiles, while `hosts/<host>/configuration.nix` contains machine settings and enables host-facing modules. Settings shared by the local site, including DNS domains, live in `hosts/site.nix`.

## Composition

Configuration is assembled in this order:

```text
flake.nix
├── hosts/<host>/default.nix          user and profile selection
├── hosts/<host>/configuration.nix    machine settings and service enablement
├── profiles/default.nix              user-specific profile module mapping
└── modules/                          globally imported reusable NixOS modules
```

Each profile entry in `profiles/default.nix` explicitly selects `homeModules` and `systemModules` for a user. Profile modules may import shared layers such as `common` or `graphical`; profile names are therefore user-specific selections rather than a global catalog.

Modules under `modules/` are imported globally and generally expose an option namespace that a host enables or configures. Their `options.nix` files are the authoritative API. Major abstractions include:

- `rootZfs` for disk layout, encryption, impermanence, and persistent state
- `podmanServer` for container, path, and derived environment-file declarations
- `storage` for shared ZFS datasets and generated paths
- `caddy` for public and authenticated HTTP ingress
- `backup` for scheduled pushes to remote targets
- `mediaServer`, `gameServer`, and `atticCache` for server workloads

The default package set is the pinned release nixpkgs. A host can intentionally select the pinned unstable package set with `useUnstablePackages`; modules and profiles can also receive `unstablePkgs` for localized use. Home Manager is evaluated as part of each NixOS configuration, and secrets are managed with agenix.

## Common Operations

Enter the development shell before running repository commands:

```bash
nix develop
just check
just dry-run <host>
just switch <host>
nix run .#create-installer -- <host> /dev/<usb-device>
```

`just switch` switches locally when `<host>` matches the current hostname; otherwise it builds and activates through SSH on that host. Valid hosts are `white-tower`, `rainbow-wave`, `pbovbel-dell`, `becmac-pro`, and `media`.

Run the full validation suite after every configuration change:

```bash
just check
just dry-run <host>
```

## Where Changes Belong

- Machine-specific policy, settings, and module enablement: `hosts/<host>/configuration.nix`
- Physical hardware facts and enablement, including device modules, disk identities, GPU support, firmware, and host platform: `hosts/<host>/hardware-configuration.nix`
- Host user and profile selection: `hosts/<host>/default.nix`
- Shared site values: `hosts/site.nix`
- Reusable NixOS behavior and public options: `modules/<name>/`
- User and system profile behavior: `profiles/<profile>/`
- Profile selection mapping: `profiles/default.nix`
- Agenix-encrypted values: `secrets/`
- Agenix recipient declarations: `secrets.nix`

Keep intentional machine policy in `configuration.nix`, including bootloader and kernel selection, network identity and behavior, services, and `rootZfs` behavior. Keep generated or hardware-bound values in `hardware-configuration.nix`; these files may be maintained manually after their initial generation.

Do not add plaintext secrets. Stateful services on impermanent hosts must declare their persistent files or directories through `rootZfs`. Server containers should use the `podmanServer` abstractions, HTTP exposure should use `caddy.sites`, and shared data should use `storage.datasets` rather than unmanaged paths.

## Adding A Host

1. Create `hosts/<host>/default.nix` with its target system, users, and profile selections.
2. Create `hosts/<host>/configuration.nix` and hardware configuration.
3. Register the host in the `hosts` attribute set in `flake.nix`.
4. Add its agenix recipient key to `secrets.nix` and rekey secrets as needed.
5. Run `just check` and `just dry-run <host>`.

For a clean installation, follow [`docs/install.md`](docs/install.md). The flake provides a flashable, host-specific USB installer for each registered host. The installation procedure repartitions the target disk and must be reviewed before use.

## Runbooks

- [Clean host installation and TPM enrollment](docs/install.md)
- [Caddy site and endpoint declarations](modules/caddy/README.md)
- [Attic cache initialization](modules/attic-cache/README.md)
