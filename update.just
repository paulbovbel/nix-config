set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# Refresh all dependency pins.
all: images nix github-actions

# Refresh image digests without changing catalog tags.
images:
    nix shell --inputs-from . nixpkgs#skopeo --command bash modules/podman-server/scripts/update-images.sh

# Refresh all Nix flake inputs.
nix:
    nix flake update

# Refresh GitHub Actions pins within their current major versions.
github-actions:
    python3 modules/github-runner/scripts/update-actions.py
