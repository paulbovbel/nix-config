set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default:
  @just --list

check: nix-lint python-lint python-test shell-lint nix-check

dry-run host=`hostname`:
  nix build ".#nixosConfigurations.{{ host }}.config.system.build.toplevel" --dry-run

build host=`hostname`:
  nix build ".#nixosConfigurations.{{ host }}.config.system.build.toplevel"

update-caddy:
  nix develop --command python3 modules/caddy/update.py

switch host=`hostname`: (_activate "switch" host)

boot host=`hostname`: (_activate "boot" host)

_activate action host:
  #!/usr/bin/env bash
  set -euo pipefail
  flake_path='{{ justfile_directory() }}'
  configuration_branch="$(git -C "${flake_path}" branch --show-current)"
  if [ -z "${configuration_branch}" ]; then
    printf 'Cannot activate from a detached HEAD; check out the intended branch first.\n' >&2
    exit 1
  fi

  # We need this repo's git branch to setup auto-upgrade, so, all builds are impure now I guess.
  export NIX_CONFIG_BRANCH="${configuration_branch}"

  configured_host="$(nix eval --impure --raw "${flake_path}#nixosConfigurations.{{ host }}.config.networking.hostName")"
  target_system="$(nix eval --impure --raw "${flake_path}#nixosConfigurations.{{ host }}.config.nixpkgs.hostPlatform.system")"
  test "${configured_host}" = '{{ host }}'

  if [ '{{ host }}' = "$(hostname)" ]; then
    sudo --preserve-env=SSH_AUTH_SOCK,NIX_CONFIG_BRANCH nixos-rebuild '{{ action }}' --impure --flake "${flake_path}#{{ host }}" -L
  else
    if [[ "${target_system}" = aarch64-* ]]; then
      # Needs access to vendorfw directory, which is not available on remote hosts.
      printf 'Remote deployment of aarch64 hosts is not supported: %s\n' '{{ host }}' >&2
      exit 1
    fi
    nixos-rebuild '{{ action }}' --impure --flake "${flake_path}#{{ host }}" --target-host '{{ host }}' --build-host '{{ host }}' --sudo --ask-sudo-password -L
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

python-test:
  python3 -m unittest discover -s modules/accounts -p 'test_*.py'
  python3 -m unittest discover -s modules/auto-upgrade -p 'test_*.py'

shell-lint:
  shellcheck $(fd -e sh .)
  shfmt -i 2 -d $(fd -e sh .)
