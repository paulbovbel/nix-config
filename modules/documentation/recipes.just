set shell := ["bash", "-eu", "-o", "pipefail", "-c"]
set positional-arguments
set working-directory := "../.."

# Build generated module documentation.
build:
    @nix build .#module-docs --no-link --print-out-paths

# Build and preview documentation at http://127.0.0.1:8000.
serve port="8000":
    docs="$(just docs build)"; python3 -m http.server {{ quote(port) }} --bind 127.0.0.1 --directory "$docs"
