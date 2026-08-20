set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default:
  @just --list

check: nix-lint python-lint shell-lint nix-check

dry-run host=`hostname`:
  nix build ".#nixosConfigurations.{{ host }}.config.system.build.toplevel" --dry-run

build host=`hostname`:
  nix build ".#nixosConfigurations.{{ host }}.config.system.build.toplevel"

switch host=`hostname`:
  #!/usr/bin/env bash
  set -euo pipefail
  flake_path='{{ justfile_directory() }}'
  configured_host="$(nix eval --raw "${flake_path}#nixosConfigurations.{{ host }}.config.networking.hostName")"
  test "${configured_host}" = '{{ host }}'
  if [ '{{ host }}' = "$(hostname)" ]; then
    sudo nixos-rebuild switch --flake "${flake_path}#{{ host }}" -L
  else
    nixos-rebuild switch --flake "${flake_path}#{{ host }}" --target-host '{{ host }}' --build-host '{{ host }}' --sudo --ask-sudo-password -L
  fi

nix-lint:
  statix check .
  deadnix .
  alejandra --check .

nix-check:
  nix flake check -L

python-lint:
  ruff check .
  ruff format --check .

shell-lint:
  shellcheck $(fd -e sh .)
  shfmt -i 2 -d $(fd -e sh .)
