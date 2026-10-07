# Graphical

The everyday GNOME desktop baseline, selectable for `pbovbel` and `rbovbel`. Gaming also reuses a graphical environment for `abovbel` without exposing graphical as a standalone selection for that user.

## System behavior

- Imports the common system baseline and shared visual configuration.
- Enables GNOME with GDM, PipeWire audio, printing, and NetworkManager.
- Joins Tailscale with the graphical tag using the laptop OAuth secret.
- Installs everyday Flatpak applications; some applications are restricted to x86-64 hosts.
- Persists desktop and network service state through `rootFs`.

Hardware-specific graphics and device configuration remain in the host configuration.

## User environment

Shared Home Manager settings configure GNOME preferences, Kitty shortcuts, browser associations, and optional desktop backgrounds. User entry points add personal wallpapers, avatars, applications, and editor settings.

Gaming and work import this baseline, so it normally does not need to be selected alongside them.
