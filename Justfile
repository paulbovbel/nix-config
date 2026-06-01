set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default:
  @just --list

all: nix-lint python-lint shell-lint nix-check

nix-lint:
  nix run nixpkgs#statix -- check .
  nix run nixpkgs#deadnix -- .
  nix run nixpkgs#alejandra -- .

nix-check:
  nix flake check -L

python-lint:
  nix run nixpkgs#ruff -- check .
  nix run nixpkgs#ruff -- format --check .

shell-lint:
  nix run nixpkgs#shellcheck -- $(nix run nixpkgs#fd -- -e sh .)
  nix run nixpkgs#shfmt -- -i 2 -d $(nix run nixpkgs#fd -- -e sh .)
