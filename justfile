set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# List available recipes.
default:
    @just --list

# Run routine repository checks in parallel.
[group('checks')]
[parallel]
check: just-lint nix-lint python-lint python-test shell-lint dashboards-check

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
boot host=`hostname`:
    deploy/remote/activate.sh boot "{{ host }}"

# Build and activate a host configuration immediately.
[group('deployment')]
switch host=`hostname`:
    deploy/remote/activate.sh switch "{{ host }}"

# Build an offline installer ISO with a reused or new host identity.
[group('deployment')]
installer-iso host key_mode *args:
    deploy/usb/build-iso.sh "{{ host }}" "{{ key_mode }}" {{ args }}

# Interactively select or explicitly provide a USB drive to write.
[group('deployment')]
installer-write image device="":
    deploy/usb/write-usb.sh "{{ image }}" "{{ device }}"

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

# Build all flake checks, including NixOS integration tests.
[group('checks')]
nix-test:
    system="$(nix eval --impure --raw --expr builtins.currentSystem)"; \
      nix build --no-link -L $(nix eval --raw ".#checks.$system" --apply 'checks: builtins.concatStringsSep " " (map (name: ".#checks.'"$system"'.${name}") (builtins.attrNames checks))')

# Test the Authentik blueprint and mapping reconciliation in disposable containers.
[group('checks')]
authentik-test:
    bash tests/authentik-containers.sh

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
    python3 -m unittest discover -s modules/media-server/download -p 'test_*.py'
    python3 -m unittest discover -s modules/media-server/library -p 'test_*.py'

# Lint and format-check shell scripts.
[group('checks')]
shell-lint:
    fd -e sh -X shellcheck
    fd -e sh -X shfmt -i 2 -d
