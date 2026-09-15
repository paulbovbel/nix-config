# Game Server

The game server module runs Abiotic Factor, Minecraft, and Valheim through the Podman server abstraction.

## Requirements

Game containers require the Podman server and shared storage. Secrets such as server passwords come from agenix, and optional public port mappings are declared through UPnP.

## Persistence

Each enabled game declares an application dataset under `storage.datasets.app.children`. Preserve these datasets; container images and writable layers are replaceable, but world and save data are not.

## Troubleshooting

Inspect `abiotic.service`, `minecraft.service`, or `valheim.service` and verify the corresponding `/storage/app/{abiotic,minecraft,valheim}` dataset is mounted. Generated secrets and settings come from `/run/podman-server/{abiotic,minecraft,valheim}.env`; inspect the matching `podman-server-<game>-env.service` when an environment file is missing. For connection failures, check Abiotic UDP 7777/27015, Minecraft TCP 25565, or Valheim UDP 2456/2457 against the firewall and generated UPnP forwards.
