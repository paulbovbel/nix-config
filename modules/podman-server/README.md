# Podman Server

The Podman server module layers repository conventions over `quadlet-nix`. Service modules declare containers, shared paths, dependencies, secret inputs, and derived environment files without creating bespoke systemd or Podman units.

## Requirements

Container declarations require `quadlet-nix`. Stateful services also require declared storage datasets, while secret environment sources require agenix-managed files.

Use `secretEnvironmentFiles` for agenix-managed values and `derivedEnvironmentFiles` when a runtime file must combine secrets, generated values, or shell-expanded variables.

## Invariants

- Container dependencies refer to keys in `podmanServer.containers`.
- Stateful container paths should come from `storage.datasets` or another declared persistent path.
- Secret values must never be placed directly in Nix store-backed environment declarations.

## Persistence

The module persists `/var/lib/containers` and `/var/lib/podman-server` when containers are active. Application data should remain in service-owned storage datasets rather than the container writable layer.

## Troubleshooting

Inspect the generated `<container>.service` unit, `apps-network.service`, and `podman-auto-update.service` before debugging Podman directly. A missing `/run/podman-server/<name>.env` file points to `podman-server-<name>-env.service` or one of its agenix inputs. Container runtime state is persisted at `/var/lib/containers` and `/var/lib/podman-server`; empty application directories should instead be traced to the service-owned `/storage/app/<service>` dataset.
