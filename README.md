# nix-config

Personal NixOS configuration for desktops, laptops, and a media server.

## Everyday Commands

```bash
nix develop
just check                          # Formatting, linting, and Python tests
just deploy hosts                   # List registered hosts
just deploy switch media            # Build and activate locally or over SSH
just deploy boot media              # Activate on next boot
just docs serve                     # Preview documentation at localhost:8000
```

Run `just --list` for command groups or `just --list deploy` for deployment
commands. Use `switch` to activate immediately or `boot` for the next boot;
omitting the host uses the current hostname.

See the [module reference](https://paulbovbel.github.io/nix-config/) for options,
the [deployment guide](modules/deployment/remote/README.md) for SSH overrides and
remote installation, and the [USB guide](modules/deployment/usb/README.md) for
offline installers and migration.

## Development

| Command | Purpose |
| --- | --- |
| `just fmt` | Format repository sources |
| `just check` | Run routine checks and Python tests |
| `just lint all` | Run static checks; select `just`, `nix`, `python`, `shell`, or `workflows` individually |
| `just test python` | Run Python unit tests |
| `just test hosts` | Evaluate all hosts without building closures |
| `just test nix <name>` | Build one flake check |
| `just test all` | Run all flake checks, including NixOS VM tests |

CI runs routine and flake checks, builds hosts marked `ciBuild`, and publishes
documentation and host closures from `main`. See the
[runner runbook](modules/github-runner/README.md) for CI access.

## Repository Layout

| Path | Purpose |
| --- | --- |
| `flake.nix`, `lib/per-system.nix` | Inputs, packages, checks, and development shells |
| `hosts/{default,mk-host}.nix` | Fleet registry and host assembly |
| `hosts/<host>/default.nix` | Host metadata and users |
| `hosts/<host>/configuration.nix` | Machine policy, module enablement, and selected user profiles |
| `hosts/<host>/hardware-configuration.nix` | Hardware facts and device identities |
| `hosts/{common,site}.nix` | Shared host settings and site values |
| `modules/<name>/` | Reusable NixOS behavior, options, scripts, tests, and documentation |
| `profiles/` | User and system profiles; see the [profile guide](profiles/README.md) |
| `overlays/default.nix` | Local package overrides |
| `images.Dockerfile` | Shared container image pins |
| `secrets/`, `agenix-rules.nix` | Encrypted secrets and recipients |

Modules are imported globally and enabled by hosts. Put public options in
`options.nix`, module tooling in local `scripts/` and `tests/` directories, and
usage documentation in a local README. Persist state through `rootFs` and keep
secrets encrypted with agenix.

## Service Guides

- [Grafana dashboards](modules/monitor/README.md)
- [Caddy sites and endpoints](modules/caddy/README.md)
- [Attic cache](modules/attic-cache/README.md)
