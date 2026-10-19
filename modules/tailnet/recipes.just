set shell := ["bash", "-eu", "-o", "pipefail", "-c"]
set positional-arguments
set working-directory := "../.."

# Generate the Tailscale policy JSON file.
policy:
    @nix build .#tailnet-policy --no-link --print-out-paths

# Validate and apply the generated Tailscale policy using explicit OAuth environment variables.
apply:
    @policy="$(just tailnet policy)"; bash modules/tailnet/scripts/apply-policy.sh "$policy"
