set shell := ["bash", "-eu", "-o", "pipefail", "-c"]
set positional-arguments

# Run static checks by language.
mod lint 'lint.just'
# Run unit tests, host evaluation, and flake checks.
mod test 'test.just'
# Refresh container image pins and Nix flake inputs.
mod update 'update.just'

# Build and activate hosts.
mod deploy 'modules/deployment/deploy.just'
# Prepare installer media and install hosts.
mod installer 'modules/deployment/installer.just'
# Build and preview module documentation.
mod docs 'modules/documentation/recipes.just'
# Manage Grafana dashboards.
mod monitor 'modules/monitor/recipes.just'
# Generate and apply the Tailscale policy.
mod tailnet 'modules/tailnet/recipes.just'

# List available recipes.
default:
    @just --list

# Format repository sources.
fmt:
    just --fmt
    fd -e just -x just --justfile {} --fmt
    alejandra .
    ruff format .
    fd -e sh -X shfmt -i 2 -w

# Run routine repository checks in parallel.
[parallel]
check: lint::all test::python monitor::check
