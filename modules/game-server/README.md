# Game Server

The game server module runs Abiotic Factor, Minecraft, and Valheim through the Podman server abstraction.

## Abiotic Factor

`gameServer.abiotic.enable` runs the dedicated server with its save data on persistent storage. Its password and other private settings come from the generated runtime environment file.

## Minecraft

`gameServer.minecraft.enable` runs the Minecraft server. The `users` and `ops` options generate its whitelist and operator files from Minecraft usernames.

## Valheim

`gameServer.valheim.enable` runs the Valheim server. Administrator and permitted-player maps associate readable names with SteamID64 values, while `gameServer.valheim.modifiers.*` controls world rules without editing server files manually. A null modifier leaves that rule at the game default.

## Network Exposure

`gameServer.upnp.enable` lets each enabled server declare its required UPnP forwards. Disable it when forwarding is managed outside this configuration.

## Requirements

Game containers require the Podman server and shared storage; passwords come from agenix.

## Persistence

Each enabled game declares an application dataset under `storage.datasets.app.children`. Preserve these datasets; container images and writable layers are replaceable, but world and save data are not.

## Troubleshooting

Inspect `abiotic.service`, `minecraft.service`, or `valheim.service` and verify the corresponding `/storage/app/{abiotic,minecraft,valheim}` dataset is mounted. Generated secrets and settings come from `/run/podman-server/{abiotic,minecraft,valheim}.env`; inspect the matching `podman-server-<game>-env.service` when an environment file is missing. For connection failures, check Abiotic UDP 7777/27015, Minecraft TCP 25565, or Valheim UDP 2456/2457 against the firewall and generated UPnP forwards.
