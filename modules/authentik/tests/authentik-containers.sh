#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
blueprint="$(nix build "$root#nixosConfigurations.media.config.authentik.blueprint" --no-link --print-out-paths)"
image="$(nix eval --raw "$root#nixosConfigurations.media.config.authentik.image")"
database_image="$(nix eval --raw "$root#nixosConfigurations.media.config.podmanServer.containers.authentik-db.quadlet.containerConfig.image")"
name="authentik-test-$(id -u)-$$"
cleanup() {
  status=$?
  if ((status != 0)); then
    podman logs "$name-db" || true
  fi
  podman rm -fv "$name-app" "$name-db" >/dev/null 2>&1 || true
  podman network rm "$name" >/dev/null 2>&1 || true
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

podman network create "$name" >/dev/null
podman run -d --name "$name-db" --network "$name" --network-alias database \
  -e POSTGRES_DB=authentik -e POSTGRES_USER=authentik -e POSTGRES_PASSWORD=test-only \
  "$database_image" >/dev/null
ready=false
for _ in {1..60}; do
  if podman exec "$name-db" pg_isready -U authentik -d authentik; then
    ready=true
    break
  fi
  sleep 1
done
if [[ "$ready" != true ]]; then
  printf 'PostgreSQL did not become ready within 60 seconds.\n' >&2
  exit 1
fi

podman run --name "$name-app" --network "$name" \
  -e AUTHENTIK_POSTGRESQL__HOST=database \
  -e AUTHENTIK_POSTGRESQL__NAME=authentik \
  -e AUTHENTIK_POSTGRESQL__USER=authentik \
  -e AUTHENTIK_POSTGRESQL__PASSWORD=test-only \
  -e AUTHENTIK_SECRET_KEY=authentik-blueprint-test-only-disposable-secret-key-for-regression-testing \
  -e AUTHENTIK_LOG_LEVEL=warning \
  -e GOOGLE_OAUTH2_CLIENT_ID=google-test \
  -e GOOGLE_OAUTH2_CLIENT_SECRET=google-test \
  -e AUTHENTIK_AUDIOBOOKSHELF_CLIENT_SECRET=audiobookshelf-test \
  -v "$blueprint:/blueprints/custom/nix-config.yaml:ro" \
  -v "$root/modules/authentik/tests:/tests:ro" \
  --entrypoint /bin/bash "$image" -ec \
  'python -m lifecycle.migrate; ak shell -c "exec(open(\"/tests/authentik-container-init.py\").read())"; ak shell -c "exec(open(\"/tests/authentik-email-mapping.py\").read())"'
