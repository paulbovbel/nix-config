set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default:
  @just --list

check: nix-lint python-lint shell-lint nix-check

dry-run host=`hostname`:
  nix build ".#nixosConfigurations.{{ host }}.config.system.build.toplevel" --dry-run

build host=`hostname`:
  nix build ".#nixosConfigurations.{{ host }}.config.system.build.toplevel"

switch host=`hostname`:
  nixos-rebuild switch --flake .#{{ host }} --target-host '{{ host }}' --build-host '{{ host }}' --sudo --ask-sudo-password -L

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
