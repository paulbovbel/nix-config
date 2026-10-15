set shell := ["bash", "-eu", "-o", "pipefail", "-c"]
set positional-arguments

# List available recipes.
default:
    @just --list

# Run routine repository checks in parallel.
[group('checks')]
[parallel]
check: just-lint nix-lint python-lint python-test shell-lint workflows-lint dashboards-check

# Build a host configuration.
[group('deployment')]
build host=`hostname` *args:
    modules/deployment/scripts/remote/activate.sh build "$@"

# Show what building a host configuration would download or build.
[group('deployment')]
build-plan host=`hostname` *args:
    modules/deployment/scripts/remote/activate.sh build-plan "$@"

alias dry-run := build-plan

# Build and preview activation changes.
[group('deployment')]
dry-activate host=`hostname` *args:
    modules/deployment/scripts/remote/activate.sh dry-activate "$@"

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
boot host=`hostname` *args:
    modules/deployment/scripts/remote/activate.sh boot "$@"

# Build and activate a host configuration immediately.
[group('deployment')]
switch host=`hostname` *args:
    modules/deployment/scripts/remote/activate.sh switch "$@"

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

# Validate and apply the generated Tailscale policy using explicit OAuth environment variables.
[group('tailscale')]
tailnet-policy-apply:
    @policy="$(just tailnet-policy)"; bash modules/tailnet/scripts/apply-policy.sh "$policy"

# Apply Grafana dashboards.
[group('grafana')]
dashboards-apply:
    @: "${GRAFANA_TOKEN:?GRAFANA_TOKEN must be set}"
    gcx resources push --config modules/monitor/gcx.yaml --context monitoring --path modules/monitor/grafana --on-error abort

# Lint Grafana dashboards.
[group('grafana')]
dashboards-check:
    gcx dev lint run modules/monitor/grafana

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
    python3 -m unittest discover -s modules/game-streaming/tests -p 'test_*.py'
    PYTHONPATH=modules/auto-upgrade/scripts python3 -m unittest discover -s modules/auto-upgrade/tests -p 'test_*.py'
    python3 -m unittest discover -s modules/media-server/download/tests -p 'test_*.py'
    python3 -m unittest discover -s modules/media-server/library/tests -p 'test_*.py'
    python3 -m unittest discover -s modules/monitor/tests -p 'test_*.py'

# Lint and format-check shell scripts.
[group('checks')]
shell-lint:
    fd -e sh -X shellcheck
    fd -e sh -X shfmt -i 2 -d

# Validate GitHub Actions workflows.
[group('checks')]
workflows-lint:
    actionlint
