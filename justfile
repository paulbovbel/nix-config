set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# List available recipes.
default:
    @just --list

# Run routine repository checks in parallel.
[group('checks')]
[parallel]
check: just-lint nix-lint python-lint python-test shell-lint workflows-lint dashboards-check

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

# Build and preview documentation at http://127.0.0.1:8000.
[group('documentation')]
docs-serve port="8000":
    docs="$(just docs)"; python3 -m http.server {{ quote(port) }} --bind 127.0.0.1 --directory "$docs"

# Activate a host configuration on the next boot.
[group('deployment')]
boot host=`hostname`:
    modules/deployment/scripts/remote/activate.sh boot "{{ host }}"

# Build and activate a host configuration immediately.
[group('deployment')]
switch host=`hostname`:
    modules/deployment/scripts/remote/activate.sh switch "{{ host }}"

# Build an offline installer ISO with a reused or new host identity.
[group('deployment')]
installer-iso host key_mode *args:
    modules/deployment/scripts/usb/build-iso.sh "{{ host }}" "{{ key_mode }}" {{ args }}

# Interactively select or explicitly provide a USB drive to write.
[group('deployment')]
installer-write image device="":
    modules/deployment/scripts/usb/write-usb.sh "{{ image }}" "{{ device }}"

# Generate the Tailscale policy JSON file.
[group('tailscale')]
tailnet-policy:
    @nix build .#tailnet-policy --no-link --print-out-paths

# Validate and apply the generated Tailscale policy using the agenix MCP credential.
[group('tailscale')]
tailnet-policy-apply:
    @policy="$(just tailnet-policy)"; bash modules/tailnet/scripts/apply-policy.sh "$policy"

# Apply Grafana dashboards.
[confirm]
[group('grafana')]
dashboards-apply:
    modules/monitor/scripts/grafana-dashboards.sh

# Lint Grafana dashboards.
[group('grafana')]
dashboards-check:
    gcx dev lint run modules/monitor/grafana

# Preview Grafana dashboard changes.
[group('grafana')]
dashboards-dry-run:
    modules/monitor/scripts/grafana-dashboards.sh --dry-run

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

# Build all flake checks, including module contracts and NixOS integration tests.
[group('checks')]
nix-test:
    nix build --no-link --keep-going -L .#ci-checks

# Test Authentik provisioning, dashboard, and reconciliation in a minimal NixOS VM.
[group('checks')]
authentik-test:
    nix build --no-link -L .#checks.x86_64-linux.authentik-blueprint

# Lint and format-check Python files.
[group('checks')]
python-lint:
    ruff check .
    ruff format --check .

# Run Python unit tests.
[group('checks')]
python-test:
    PYTHONPATH=modules/documentation/scripts python3 -m unittest discover -s modules/documentation/tests -p 'test_*.py'
    PYTHONPATH=modules/accounts/scripts python3 -m unittest discover -s modules/accounts/tests -p 'test_*.py'
    PYTHONPATH=modules/auto-upgrade/scripts python3 -m unittest discover -s modules/auto-upgrade/tests -p 'test_*.py'
    python3 -m unittest discover -s modules/media-server/download/tests -p 'test_*.py'
    python3 -m unittest discover -s modules/media-server/library/tests -p 'test_*.py'

# Lint and format-check shell scripts.
[group('checks')]
shell-lint:
    fd -e sh -X shellcheck
    fd -e sh -X shfmt -i 2 -d

# Validate GitHub Actions workflows.
[group('checks')]
workflows-lint:
    actionlint
