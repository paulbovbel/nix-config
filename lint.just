set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# Run all static checks in parallel.
[parallel]
all: just nix python shell workflows

# Check Just formatting, including module files.
just:
    just --fmt --check
    fd -e just -x just --justfile {} --fmt --check

# Lint and format-check Nix files.
nix:
    statix check .
    deadnix .
    alejandra --check .

# Lint and format-check Python files.
python:
    ruff check .
    ruff format --check .

# Lint and format-check shell scripts.
shell:
    fd -e sh -X shellcheck
    fd -e sh -X shfmt -i 2 -d

# Validate GitHub Actions workflows.
workflows:
    actionlint
