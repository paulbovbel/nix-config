# Hyprland with Caelestia

Uses [Caelestia's Hyprland dotfiles](https://github.com/caelestia-dots/caelestia)
with [Caelestia Shell](https://github.com/caelestia-dots/shell) and its CLI.
Caelestia supplies the bar, launcher, notifications, dashboard, wallpaper picker,
lock screen, idle handling, and coordinated Hyprland behavior.

The `caelestia-shell` flake provides the upstream Home Manager module and matching
shell/CLI/Quickshell packages, built against the existing unstable input. The
`caelestia-dots` source input supplies the Hyprland Lua configuration, window
rules, animations, gestures, and keybindings. Hyprland itself uses the host's
selected nixpkgs.

## Selection

Select the shell independently of user profiles in the host's `configuration.nix`:

```nix
userProfiles = {
  pbovbel = {
    profiles = ["work" "gaming"];
    shell = "hyprland";
  };
  rbovbel.profiles = ["graphical"]; # GNOME by default
};
```

Each user defaults to GNOME unless their `shell` is set to `"hyprland"`. The
example keeps `rbovbel` on GNOME while `pbovbel` uses Caelestia.
Both desktop environments are installed, and GDM's per-user login preferences
follow these selections. After rebuilding, log out and back in to enter the
selected desktop.

Caelestia, clipboard history, and the authentication agent start with
`hyprland-session.target` and stop when the session ends. XDG autostart
applications are also started. Caelestia handles locking after 15 minutes,
display power-off after 20 minutes, and locking before suspend.

## Keybindings

These follow upstream Caelestia defaults. `Super` is the Windows key.

| Binding | Action |
| --- | --- |
| Super (press and release) | Application launcher |
| Super + T | Kitty |
| Super + W / C / E | Firefox / editor / file manager |
| Super + Q | Close window |
| Super + F | Fullscreen |
| Super + Alt + Space | Toggle floating |
| Super + arrows | Focus window |
| Super + Shift + arrows | Move window |
| Super + 1–9, 0 | Workspace 1–10 |
| Super + Alt + 1–9, 0 | Move window to workspace |
| Super + left/right mouse drag | Move/resize window |
| Super + V / Period | Clipboard / emoji picker |
| Super + N | Sidebar |
| Super + K | Show shell panels |
| Super + L | Lock |
| Ctrl + Alt + Delete | Session menu |
| Print | Screenshot |
| Super + Shift + S | Freeze screenshot |
| Ctrl + Super + Alt + R | Restart Caelestia's systemd service |

The launcher accepts `>wallpaper` for wallpapers and `>settings` for shell settings.
Full bindings are documented in the [upstream dotfiles README](https://github.com/caelestia-dots/caelestia#default-keybinds).

## Host integration and customization

The adapter in `home.nix` configures Kitty, the existing Firefox Flatpak, VS Code,
Nautilus, and Pavucontrol. It uses the host keyboard layout and existing cursor,
avatar, and wallpaper. GTK, Qt, and terminal themes remain managed by the shared
graphical configuration; Caelestia can manage its own palette, Hyprland colors,
and Fuzzel theme.

Home Manager owns the Hyprland configuration and the user override files:

- `~/.config/caelestia/hypr-vars.lua`: application and cursor overrides.
- `~/.config/caelestia/hypr-user.lua`: keyboard layout and toolkit integration.
- `~/.config/caelestia/shell.json`: shell settings from `programs.caelestia.settings`.
- `~/.config/caelestia/cli.json`: CLI settings from `programs.caelestia.cli.settings`.

Edit the Nix adapter to customize these files. Caelestia owns the mutable
`~/.config/hypr/scheme/current.lua` and its state under
`~/.local/state/caelestia`. On first session startup, the CLI initializes the
palette and personal wallpaper. Later wallpaper choices are preserved.
Wallpapers are read from `~/.local/share/backgrounds`; the dashboard avatar is
linked at `~/.face`.

White Tower's host configuration appends a 125% monitor scale override for
`pbovbel` after the upstream defaults. Other Hyprland users use Caelestia's
default scale of 1 unless overridden.

Upstream startup commands are replaced by Home Manager services while the
window-resizer listeners are retained. The shell's password authentication is
adapted to the generated NixOS `caelestia` PAM service; fingerprint support is
enabled on hosts that enable fprintd.

Update the desktop inputs with:

```bash
nix flake update caelestia-shell caelestia-dots
```

For diagnostics, use `journalctl --user -u caelestia`,
`systemctl --user status hyprland-session.target`, and `hyprctl configerrors`.
