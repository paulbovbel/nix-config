# Podman Server

The Podman server module layers repository conventions over `quadlet-nix`. Service modules declare containers, shared paths, dependencies, secret inputs, and derived environment files without creating bespoke systemd or Podman units.

## Host Identity

`podmanServer.user.*` defines the host user and group that own rootless containers and shared application paths. The numeric IDs are also passed to containers that need ownership aligned with the host.

## Containers And Paths

`podmanServer.containers` contains named Quadlet declarations plus repository-specific dependency and environment-file settings. `podmanServer.paths` publishes named host paths so service modules can share generated storage locations without repeating them.

## Derived Environment Files

`podmanServer.derivedEnvFiles` declares runtime-generated files that combine public values, secret environment files, other derived files, and shell-expanded variables. Containers reference them by name through `derivedEnvironmentFiles`, which also establishes startup ordering.

## Requirements

Use `secretEnvironmentFiles` for agenix-managed values and `derivedEnvironmentFiles` when a runtime file combines secrets or generated values.

## Invariants

- Container dependencies refer to keys in `podmanServer.containers`.
- Stateful container paths should come from `storage.datasets` or another declared persistent path.
- Secret values must never be placed directly in Nix store-backed environment declarations.

## Persistence

The module persists `/var/lib/containers` and `/var/lib/podman-server` when containers are active. Application data should remain in service-owned storage datasets rather than the container writable layer.

## Troubleshooting

Inspect `<container>.service` and `apps-network.service`; for update failures check `podman-auto-update.service`. A missing `/run/podman-server/<name>.env` points to `podman-server-<name>-env.service` or its agenix inputs. For empty application directories, check the service's storage dataset.
