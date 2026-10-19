set shell := ["bash", "-eu", "-o", "pipefail", "-c"]
set positional-arguments

# Build all flake checks, including host evaluation, contracts, and NixOS VM tests.
all:
    nix build --no-link --keep-going -L .#ci-checks

# Build one flake check for this machine's architecture.
nix name *args:
    system="$(nix eval --impure --raw --expr builtins.currentSystem)"; nix build --no-link -L ".#checks.$system.$1" "${@:2}"

# Evaluate every host without building system closures or VM tests.
hosts: (nix "host-evaluations")

# Run Python unit tests.
python:
    python3 -m unittest discover -s modules/deployment/tests -p 'test_*.py'
    PYTHONPATH=modules/documentation/scripts python3 -m unittest discover -s modules/documentation/tests -p 'test_*.py'
    PYTHONPATH=modules/accounts/scripts python3 -m unittest discover -s modules/accounts/tests -p 'test_*.py'
    python3 -m unittest discover -s modules/game-streaming/tests -p 'test_*.py'
    PYTHONPATH=modules/auto-upgrade/scripts python3 -m unittest discover -s modules/auto-upgrade/tests -p 'test_*.py'
    python3 -m unittest discover -s modules/media-server/download/tests -p 'test_*.py'
    python3 -m unittest discover -s modules/media-server/library/tests -p 'test_*.py'
    python3 -m unittest discover -s modules/monitor/tests -p 'test_*.py'
