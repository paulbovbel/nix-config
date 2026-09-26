set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# List available recipes.
default:
    @just --list

# Run all repository checks in parallel.
[group('checks')]
[parallel]
check: just-lint nix-lint python-lint python-test shell-lint dashboards-check nix-check

# Build a host configuration.
[group('deployment')]
build host=`hostname`:
    nix build ".#nixosConfigurations.{{ host }}.config.system.build.toplevel"

# Show what building a host configuration would download or build.
[group('deployment')]
dry-run host=`hostname`:
    nix build ".#nixosConfigurations.{{ host }}.config.system.build.toplevel" --dry-run

# Build generated module documentation.
[group('documentation')]
docs:
    @nix build .#module-docs --no-link --print-out-paths

# Activate a host configuration on the next boot.
[group('deployment')]
boot host=`hostname`: (_activate "boot" host)

# Build and activate a host configuration immediately.
[group('deployment')]
switch host=`hostname`: (_activate "switch" host)

# Build an offline installer ISO with a reused or new host identity.
[group('deployment')]
installer-iso host key_mode *args:
    installer/build-iso.sh "{{ host }}" "{{ key_mode }}" {{ args }}

# Apply Grafana dashboards.
[confirm]
[group('grafana')]
dashboards-apply:
    monitoring/grafana-dashboards.sh

# Lint Grafana dashboards.
[group('grafana')]
dashboards-check:
    gcx dev lint run monitoring/grafana

# Preview Grafana dashboard changes.
[group('grafana')]
dashboards-dry-run:
    monitoring/grafana-dashboards.sh --dry-run

# Update generated Caddy configuration.
[group('maintenance')]
update-caddy:
    nix develop --command python3 modules/caddy/update.py

# Build and activate a local or remote host.
[private]
_activate action host:
    #!/usr/bin/env bash
    set -euo pipefail
    flake_path='{{ justfile_directory() }}'
    configuration_branch="$(git -C "${flake_path}" branch --show-current)"
    if [ -z "${configuration_branch}" ]; then
      printf 'Cannot activate from a detached HEAD; check out the intended branch first.\n' >&2
      exit 1
    fi

    # Auto-upgrade needs this repository's branch, so activation must be impure.
    export NIX_CONFIG_BRANCH="${configuration_branch}"

    configured_host="$(nix eval --impure --raw "${flake_path}#nixosConfigurations.{{ host }}.config.networking.hostName")"
    test "${configured_host}" = '{{ host }}'

    if [ '{{ host }}' = "$(hostname)" ]; then
      sudo --preserve-env=SSH_AUTH_SOCK,NIX_CONFIG_BRANCH nixos-rebuild '{{ action }}' --impure --flake "${flake_path}#{{ host }}" -L
    else
      target_system="$(nix eval --impure --raw "${flake_path}#nixosConfigurations.{{ host }}.config.nixpkgs.hostPlatform.system")"
      if [[ "${target_system}" = aarch64-* ]]; then
        # The required vendorfw directory is unavailable on remote hosts.
        printf 'Remote deployment of aarch64 hosts is not supported: %s\n' '{{ host }}' >&2
        exit 1
      fi

      nixos-rebuild '{{ action }}' --impure --flake "${flake_path}#{{ host }}" --target-host '{{ host }}' --build-host '{{ host }}' --sudo --ask-sudo-password -L
    fi

# Check justfile formatting.
[group('checks')]
just-lint:
    just --fmt --check

# Lint Nix files.
[group('checks')]
nix-lint:
    statix check .
    deadnix .
    alejandra --check .

# Evaluate flake checks.
[group('checks')]
nix-check:
    nix flake check -L

# Lint and format-check Python files.
[group('checks')]
python-lint:
    ruff check .
    ruff format --check .

# Run Python unit tests.
[group('checks')]
python-test:
    python3 -m unittest discover -s docs -p 'test_*.py'
    python3 -m unittest discover -s modules/accounts -p 'test_*.py'
    python3 -m unittest discover -s modules/auto-upgrade -p 'test_*.py'
    python3 -m unittest discover -s modules/media-server/library -p 'test_*.py'

# Lint and format-check shell scripts.
[group('checks')]
shell-lint:
    fd -e sh -X shellcheck
    fd -e sh -X shfmt -i 2 -d
