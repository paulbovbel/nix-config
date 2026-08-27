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
  configured_host="$(nix eval --impure --raw "${flake_path}#nixosConfigurations.{{ host }}.config.networking.hostName")"
  target_system="$(nix eval --impure --raw "${flake_path}#nixosConfigurations.{{ host }}.config.nixpkgs.hostPlatform.system")"
  test "${configured_host}" = '{{ host }}'
  if [ '{{ host }}' = "$(hostname)" ]; then
    if [[ "${target_system}" = aarch64-* ]]; then
      sudo nixos-rebuild switch --impure --flake "${flake_path}#{{ host }}" -L
    else
      sudo nixos-rebuild switch --flake "${flake_path}#{{ host }}" -L
    fi
  else
    if [[ "${target_system}" = aarch64-* ]]; then
      # Needs access to vendorfw directory, which is not available on remote hosts.
      printf 'Remote deployment of aarch64 hosts is not supported: %s\n' '{{ host }}' >&2
      exit 1
    fi
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
