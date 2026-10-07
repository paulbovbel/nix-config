# Podman Server

The Podman server module layers repository conventions over `quadlet-nix`. Service modules declare containers, shared paths, dependencies, secret inputs, and derived environment files without creating bespoke systemd or Podman units.

## Host Identity

`podmanServer.user.*` defines the host user and group that own shared application paths. The numeric IDs are also passed to containers that need ownership aligned with the host.

Containers run through system-level Quadlet services using rootful Podman. Application UID/GID settings control ownership and container process identity where configured; they do not make Podman rootless.

## Containers And Paths

`podmanServer.containers` contains named Quadlet declarations plus repository-specific dependency and environment-file settings. `podmanServer.paths` publishes named host paths so service modules can share generated storage locations without repeating them.

Containers use `podmanServer.containers.<name>`. `dependsOn` names other declared
containers; `derivedEnvironmentFiles` names entries in `podmanServer.derivedEnvFiles`.
Both dependency graphs must be acyclic, and all references must exist.

## Published ports

Use `ports` to publish ports and choose firewall and router-forwarding policy:

```nix
podmanServer.containers.example.ports = [
  { hostPort = 8080; containerPort = 80; exposure = [ "tailnet" ]; }
  { hostPort = 32400; exposure = [ "wan" "tailnet" ]; }
  { hostPort = 9000; bindAddress = "127.0.0.1"; }
  { hostPort = 10000; containerPort = 20000; count = 10; protocol = "udp"; exposure = [ "wan" ]; }
];
```

`containerPort` defaults to `hostPort`; `protocol` defaults to `tcp`. `count`
publishes equal-sized consecutive ranges. IPv6 bind addresses omit brackets, for
example `bindAddress = "::1"`.

`exposure` defaults to `[]`, publishing without generating firewall openings.
Omit `ports` entirely for container-internal access, including Caddy backends.
`tailnet` opens ports only on `services.tailscale.interfaceName` (normally
`tailscale0`); Tailscale grants/ACLs still apply. `wan` opens ports globally, which
also permits LAN traffic. There is no dedicated LAN exposure policy. Host SSH
access is managed separately. Declare both `wan` and `tailnet` when both access
scopes are intended, preserving that intent for future ACL integration.

WAN ports always request UPnP forwards. Each forward uses the same external and
host port and protocol, even when `containerPort` differs. The UPnP module
refreshes mappings periodically. Caddy requests mappings for ports 80, 443, and
every custom domain listener port.
UPnP requires `bindAddress = null` or `"0.0.0.0"`, because mappings target the
host's detected LAN IPv4 address.

Raw `quadlet.containerConfig.publishPorts` entries remain available for advanced
Podman syntax, but generate no firewall rules or UPnP forwards; declare any
required rules separately.

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
