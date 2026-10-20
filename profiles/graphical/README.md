# Graphical

The everyday graphical baseline, selectable for `pbovbel` and `rbovbel`. Gaming also reuses a graphical environment for `abovbel` without exposing graphical as a standalone selection for that user.

## Shell choice

Select the desktop shell independently of user profiles in the host's
`configuration.nix`:

```nix
userProfiles = {
  pbovbel = {
    profiles = ["work" "gaming"];
    shell = "hyprland";
  };
  rbovbel.profiles = ["graphical"]; # GNOME by default
};
```

`userProfiles.<user>.shell` defaults to `"gnome"`. Shell selection applies when
that user's `profiles` list includes the graphical baseline, either directly or
through inheritance. Selecting `"hyprland"` requires a graphical profile and includes
[Caelestia's shell and Hyprland dotfiles](shells/hyprland/README.md).

Each user receives only their selected shell's Home Manager configuration. The
host enables all required desktop environments, so GNOME and Hyprland can coexist.
The `graphical-user-sessions` service sets each user's GDM login preference through
AccountsService at boot and when the configuration changes. AccountsService state
is persisted. Users can also choose an installed session in GDM's session selector.
Work, gaming, shared applications, and desktop services compose with either shell.

## System behavior

- Imports the common system baseline and shared visual configuration.
- Enables the shells required by graphical users with GDM, PipeWire audio, printing, and NetworkManager.
- Joins Tailscale with the graphical tag using the laptop OAuth secret.
- Installs everyday Flatpak applications; some applications are restricted to x86-64 hosts.
- Persists desktop and network service state through `rootFs`.

Hardware-specific graphics and device configuration remain in the host configuration.

## User environment

Shared Home Manager settings configure Kitty shortcuts, browser associations, and optional desktop backgrounds. Shell-specific settings configure GNOME preferences or Caelestia's Hyprland desktop. User entry points add personal wallpapers, avatars, applications, and editor settings.

Gaming and work import this baseline, so it normally does not need to be selected alongside them.
