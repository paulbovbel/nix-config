set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# Run all static checks in parallel.
[parallel]
all: just nix python shell workflows yaml markdown spelling secrets

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
    zizmor --offline .github/workflows

# Validate YAML syntax and style.
yaml:
    yamllint .

# Check documentation style.
markdown:
    markdownlint-cli2

# Check spelling in source and documentation.
spelling:
    typos

# Scan the working tree, including uncommitted changes, without printing secrets.
secrets:
    gitleaks dir --redact --no-banner .
