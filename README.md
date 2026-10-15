# nix-config

Personal NixOS configuration for desktops, laptops, and a media server.

## Quick Start

Enter the development shell before running repository commands:

```bash
nix develop
just check
just docs
just hosts
just build-plan <host>
just switch <host>
```

`just switch` activates locally or through SSH, depending on the host. Browse the [module reference](https://paulbovbel.github.io/nix-config/) online, or run `just docs-serve` and open http://127.0.0.1:8000/.

## Deployment Commands

| Command | Purpose |
| --- | --- |
| `just hosts` | List registered hosts |
| `just build [host]` | Build without activation; output at `result-<host>` |
| `just build-plan [host]` | Preview downloads and builds; `dry-run` is an alias |
| `just dry-activate [host]` | Build and preview activation changes |
| `just switch [host]` | Activate immediately |
| `just boot [host]` | Activate on next boot |
| `just installer-key <host> reuse\|new` | Prepare encrypted identity payloads |
| `just installer-state <host> <archive> [--close-apps]` | Capture encrypted migration state |
| `just installer-iso <host> [--state <archive>]` | Build from prepared payloads at `result-installer-<host>` |
| `just installer-write <image> [device]` | Write an ISO to USB |
| `just install <host> root@<address>` | Install remotely using the prepared identity |

Build and activation commands default to the current hostname. Activation uses
the target host as its builder for SSH deployments. Override the destination and
builder independently:

```bash
just switch media --target pbovbel@192.168.1.10
just switch media --build-host localhost
just boot media --build-host another-builder
```

`localhost` builds on the controller; another builder must support the target
architecture. There is no blanket restriction on remote aarch64 activation.
Apple Silicon installation uses the USB path to preserve its existing partitions
and stage vendor firmware. Evaluation for Apple Silicon activation also requires
the host's `/boot/vendorfw` on the controller; the wrapper checks for it explicitly.

Build planning and activation use the same checkout branch and revision metadata.
Deploy from an attached branch. Dirty checkouts disable automatic upgrades until
a clean configuration is activated. Prepare identities and review/commit recipient
and secret changes before building installation media or installing remotely.
The build and activation recipes forward additional Nix/rebuild arguments while
preserving shell argument boundaries.

## Fleet

| Host | Purpose | Users and profiles |
| --- | --- | --- |
| `white-tower` | Primary desktop | pbovbel: [gaming](profiles/gaming/README.md); rbovbel: [graphical](profiles/graphical/README.md) |
| `rainbow-wave` | Kids gaming desktop | pbovbel: [gaming](profiles/gaming/README.md); abovbel: [gaming](profiles/gaming/README.md) |
| `pbovbel-dell` | Work laptop | pbovbel: [work](profiles/work/README.md), [gaming](profiles/gaming/README.md) |
| `becmac-pro` | Personal laptop | pbovbel: [graphical](profiles/graphical/README.md); rbovbel: [graphical](profiles/graphical/README.md) |
| `media` | Media, game, cache, ingress, and storage server | pbovbel: [base](profiles/base/README.md) |

## Architecture

`hosts/default.nix` registers the fleet; `hosts/mk-host.nix` assembles hosts. The profile module applies typed `userProfiles` selections from host configurations using the registry in `profiles/default.nix`. Reusable modules are imported globally and enabled in host configurations.

See [Profiles](profiles/README.md) for selection, composition, and role behavior.

Core modules (see the [module reference](https://paulbovbel.github.io/nix-config/) for options):

- `rootFs` for filesystems, encryption, impermanence, and persistent state
- `podmanServer` for containers and their environment files
- `storage` for shared ZFS datasets and generated paths
- `caddy.sites` for public and authenticated HTTP ingress
- `backup` for scheduled pushes to remote targets
- `mediaServer`, `gameServer`, and `atticCache` for server workloads

Hosts use pinned release nixpkgs by default, Home Manager for user environments, and agenix for secrets.

## Development

- `just check`: formatting, linting, and Python unit tests.
- `just fmt`: format Just, Nix, Python, and shell sources.
- `just host-eval`: evaluate the fleet without building host closures or VM tests.
- `just nix-check <name>`: build one flake check for the current architecture.
- `just nix-test`: host evaluation, module contracts, documentation checks, and NixOS VM tests.

CI runs both and builds hosts marked `ciBuild`. Successful `main` runs publish documentation and host closures. See the [runner runbook](modules/github-runner/README.md) for CI access and branch protection.

Document public options in `options.nix` and module usage in a local README. Never commit plaintext secrets; declare persistent state through `rootFs`.

## Repository Layout

- Flake inputs and host assembly: `flake.nix`; per-platform packages, checks, and development shells: `lib/per-system.nix`
- Shared runtime LAN discovery commands: `lib/lan-commands.nix`, imported by Podman and UPnP
- Machine policy and module enablement: `hosts/<host>/configuration.nix`
- Hardware facts and device identities: `hosts/<host>/hardware-configuration.nix`
- Host metadata and users: `hosts/<host>/default.nix`
- Shared host inventory and composition: `hosts/{default,mk-host}.nix`; shared host settings: `hosts/common.nix`
- Supported accounts, module paths, and child-account defaults: `modules/accounts/registry.nix`
- Local package overrides: `overlays/default.nix`
- Shared container image pins: `images.Dockerfile`, parsed by `modules/podman-server/read-images.nix` and passed to workloads by `flake.nix`
- Shared site values: `hosts/site.nix`
- Reusable NixOS behavior and public options: `modules/<name>/`
- Module scripts, tests, and static assets: `modules/<name>/{scripts,tests,assets}/`
- Composite-module scripts and tests: `modules/<name>/<submodule>/{scripts,tests}/`
- Profile-only Home Manager scripts: `profiles/<profile>/home/scripts/`
- User and system profiles: `profiles/<profile>/`, registered in `profiles/default.nix` and selected through `userProfiles`
- Encrypted secrets and recipients: `secrets/`, `agenix-rules.nix`

## Runbooks

- [Install and deploy a host remotely](modules/deployment/remote/README.md)
- [Build an offline USB installer](modules/deployment/usb/README.md)
- [Manage Grafana dashboards](modules/monitor/README.md)
- [Caddy site and endpoint declarations](modules/caddy/README.md)
- [Attic cache initialization](modules/attic-cache/README.md)
