set shell := ["bash", "-eu", "-o", "pipefail", "-c"]
set positional-arguments
set working-directory := "../.."

# List registered deployment hosts.
hosts:
    @nix eval --json .#lib.hostNames | jq -r '.[]'

# Activate on next boot.
boot host=`hostname` *args:
    modules/deployment/scripts/remote/activate.sh boot "$@"

# Build and activate immediately.
switch host=`hostname` *args:
    modules/deployment/scripts/remote/activate.sh switch "$@"
