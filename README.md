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

`just switch` activates locally or through SSH, depending on the host. Browse the [module reference](https://paulbovbel.github.io/nix-config/) online, or run `just docs-serve` and open http://127.0.0.1:8000/.

## Fleet

| Host | Purpose | Users and profiles |
| --- | --- | --- |
| `white-tower` | Primary desktop | pbovbel: [gaming](profiles/gaming/README.md); rbovbel: [graphical](profiles/graphical/README.md); abovbel: [gaming](profiles/gaming/README.md) |
| `rainbow-wave` | Kids gaming desktop | pbovbel: [gaming](profiles/gaming/README.md); abovbel: [gaming](profiles/gaming/README.md) |
| `pbovbel-dell` | Work laptop | pbovbel: [work](profiles/work/README.md), [gaming](profiles/gaming/README.md) |
| `becmac-pro` | Personal laptop | pbovbel: [graphical](profiles/graphical/README.md); rbovbel: [graphical](profiles/graphical/README.md) |
| `media` | Media, game, cache, ingress, and storage server | pbovbel: [headless](profiles/headless/README.md) |

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
- `just nix-test`: host evaluation, module contracts, documentation checks, and NixOS VM tests.

CI runs both and builds hosts marked `ciBuild`. Successful `main` runs publish documentation and host closures. See the [runner runbook](modules/github-runner/README.md) for CI access and branch protection.

Document public options in `options.nix` and module usage in a local README. Never commit plaintext secrets; declare persistent state through `rootFs`.

## Repository Layout

- Machine policy and module enablement: `hosts/<host>/configuration.nix`
- Hardware facts and device identities: `hosts/<host>/hardware-configuration.nix`
- Host metadata and users: `hosts/<host>/default.nix`
- Shared host inventory and composition: `hosts/{default,mk-host}.nix`
- Local package overrides: `overlays/default.nix`
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
