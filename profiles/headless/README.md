# Headless

The server-oriented profile for `pbovbel`, providing the common system baseline and personal command-line environment without a desktop.

## System behavior

- Imports shared boot, core, mail, and service settings.
- Joins Tailscale with the headless tag, enables server routing, and advertises an exit node.
- Persists Tailscale state through `rootFs`.
- Allows the configured Podman service user to request Tailscale certificates.

The server OAuth secret supplies Tailscale authentication. Host configuration selects storage and application services; headless does not enable all server workloads automatically.

## User environment

Imports `common/home/pbovbel.nix` for the personal CLI setup. This profile is currently selectable only for `pbovbel` and is used by the media server.
