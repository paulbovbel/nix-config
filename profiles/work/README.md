# Work

The development and workplace profile for `pbovbel`, built on the [graphical baseline](../graphical/README.md).

## System behavior

- Enables Podman with Docker-compatible commands and container development tooling.
- Imports the Locus VPN client with split tunneling and NetworkManager integration.
- Adds Slack and Zoom as Flatpak applications.
- Persists VPN state under `/etc/ipsec.d`.

This profile depends on the private Locus VPN flake input. Host hardware and network-specific policy remain in the host configuration.

## User environment

Extends the personal graphical environment with workplace applications and development helpers. User services create Ubuntu Distroboxes, and Kitty split shortcuts open development environments. Slack and Zoom start at login.

## Combining with gaming

Select `userProfiles.pbovbel = ["work" "gaming"]` to retain gaming tools and shared Steam storage while using work-oriented startup behavior. The [gaming profile](../gaming/README.md) suppresses Steam and personal gaming autostart when it sees `work` in `profiles.selected`.
