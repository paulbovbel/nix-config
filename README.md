# nix-config

## Overview

Hosts are declared in `hosts/default.nix` with `users`; `flake.nix` imports this inventory and loads each host module from `hosts/<host>/configuration.nix` by convention. Host-level modules are enabled in each host's `configuration.nix`.

Inventory schema in `hosts/default.nix`:

- host key: `<host>`
- `tailscaleDomain`: tailnet MagicDNS domain used for generated hostnames
- `useUnstablePackages`: use `nixpkgs-unstable` as the host-wide `pkgs` package set instead of release nixpkgs (optional, default `false`)
- `users`: list of `{ name, profiles }`

User profiles are mapped in `profiles/default.nix` to Home Manager and NixOS modules from the same profile slice. `flake.nix` imports both sides of each selected profile and deduplicates shared system modules.

- `pbovbel`: `headless`, `graphical`, `work`, `gaming`
- `rbovbel`: `graphical`
- `abovbel`: `gaming`
- Shared profile behavior lives in `profiles/<profile>/{system,home}.nix`.
- Per-user Home Manager behavior lives beside it in `profiles/<profile>/home/<user>.nix`.

Run the full local check suite before commit/PR:

```bash
just check
just dry-run <host>
```

### Repository layout

- `hosts/` host inventory in `hosts/default.nix` plus machine-specific NixOS configs
- `modules/` host-level NixOS modules (each module is a directory with `default.nix`)
- `profiles/` layered NixOS, shared Home Manager, and per-user profile behavior
- `modules/accounts/` globally imported user account NixOS modules
- `secrets/` agenix-encrypted secrets
- `secrets.nix` agenix public key declarations
- `assets/` static assets (wallpapers, etc.)

### Modules

Modules in `modules/` are imported globally by `flake.nix`. Host-facing modules expose options such as `*.enable` and are enabled from `hosts/<host>/configuration.nix`; plumbing modules activate from the declarations they own.

```text
modules/
├── attic-cache        atticd server and watch-store client
├── caddy              public ingress, auth, Caddyfile, fail2ban, share
├── ddns               Route53 dynamic DNS
├── game-server        game services
│   ├── abiotic        Abiotic Factor container
│   └── minecraft      Minecraft container
├── root-zfs           ZFS root layout, encryption, and optional impermanence
│   ├── disk           disko/ZFS disk layout
│   └── system         rollback, snapshots, persistence plumbing
├── llama-cpp          LLM server proxy
├── media-server       media services
│   ├── download       download clients
│   │   ├── books      book downloads
│   │   ├── torrent    torrent client
│   │   └── video      video downloads
│   └── library        media libraries
│       ├── books      book library
│       ├── jellyfin   Jellyfin server
│       └── plex       Plex server
├── monitor            host monitoring
│   ├── cockpit        Cockpit web UI and PCP metrics
│   └── smokeping      Smokeping container and Caddy endpoint
├── netboot            netboot.xyz ESP installation
├── nvidia             proprietary NVIDIA driver setup
├── podman-server      shared Quadlet/runtime plumbing
├── storage            shared storage paths and ZFS datasets
├── syncthing          native Syncthing service and endpoint
└── upnp               declarative port forwards
```

### Caddy ingress

Services expose HTTP routes by declaring `caddy.sites.<site>.endpoints.<name>` from their owning module. Host configs should generally only enable `caddy` and set users/roles; service modules own their own route declarations.

Endpoint shape:

```nix
caddy.sites.media.endpoints.example = {
  type = "proxy";
  path = "/example";
  host = "example";
  port = 8080;
  role = "admin";
};
```

- Use `auth = null` for intentionally public endpoints.
- Use `spoofBasic = true` when the upstream should receive the shared web basic-auth credentials.
- Use `headerUp` for upstream request headers.
- Use `stripPrefix` or `handlePath` for applications that need path-prefix handling.
- Public or authenticated HTTP exposure should use `caddy.sites` rather than hand-written Caddyfile fragments.
- The module asserts common mistakes during evaluation, including missing proxy `host`/`port`, missing OAuth roles, undeclared roles, duplicate paths within a site, and duplicate domain/listen-port pairs.
- A route audit is generated at `/etc/caddy/routes.md` on Caddy hosts.

### Profiles

Profiles are selected indirectly from the host's user declarations. Each slice keeps its NixOS module, shared Home Manager module, and per-user Home Manager modules together. Composition remains import-driven: `graphical` and `headless` import `common`, while `work` and `gaming` import `graphical`.

```text
profiles/
├── common/
│   ├── system.nix
│   ├── home.nix
│   └── home/
├── graphical/
│   ├── system.nix
│   ├── home.nix
│   └── home/
├── gaming/
├── work/
└── headless/
```
- `common` sets shared Nix settings, Cachix integration, agenix identity paths, base packages, SSH, sudo, locale, and persistent state defaults
- `graphical` adds GNOME, GDM, Flatpak, PipeWire, NetworkManager, Tailscale laptop enrollment, theming, and graphical persistence
- `headless` adds server Tailscale enrollment and headless persistence on top of `common`
- `gaming` adds Steam, Sunshine, GameMode, 32-bit graphics support, and a persistent Steam library on top of `graphical`
- `work` adds Podman/Docker compatibility, VPN tooling, work secrets, Slack, and Zoom on top of `graphical`

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

# Handle nix-cache.bovbel.com potentially being down
NIX_CONFIG=$'substituters = https://cache.nixos.org https://nix-community.cachix.org https://cuda-maintainers.cachix.org' \
nix run github:numtide/nixos-anywhere -- \
  --no-use-machine-substituters \
  --debug -L --show-trace \
  --option substituters "https://cache.nixos.org https://nix-community.cachix.org https://cuda-maintainers.cachix.org" \
  --flake .#"$host_name" \
  --phases disko,install,reboot \
  --extra-files "$tmpdir" \
  "$target_host"

rm -rf "$tmpdir"
```

Post-install TPM2 auto-unlock enrollment for hosts with `rootZfs.encrypted = true` (run on installed host after first boot):

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
