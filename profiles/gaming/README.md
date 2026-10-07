# Gaming

The desktop gaming profile for `pbovbel` and `abovbel`, built on the [graphical baseline](../graphical/README.md).

## System behavior

- Enables Steam, Proton tooling, GameMode, and 32-bit graphics support.
- Provides launchers and performance overlays for native and compatibility-layer games.
- Creates a shared `/steam-library` root filesystem volume with automatic snapshots disabled.
- Opens Steam Remote Play and dedicated-server firewall ports.

The host must provide an appropriate `rootFs` layout and GPU configuration. Game streaming and hosted game servers are separate modules enabled by the host.

## User environment

Each user's Steam `steamapps` directory links to `/steam-library/<user>`. Steam starts silently at login by default; `pbovbel` also receives Discord autostart and gaming favorites.

When [work](../work/README.md) is explicitly selected, Steam autostart is suppressed. For `pbovbel`, Discord autostart and the additional gaming favorites are also suppressed. Gaming software and storage remain available.
