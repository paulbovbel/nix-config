set shell := ["bash", "-eu", "-o", "pipefail", "-c"]
set positional-arguments
set working-directory := "../.."

# Install a host remotely using its prepared encrypted identity (destructive).
install host target:
    bash modules/deployment/scripts/remote/install.sh "$@"

# Prepare an encrypted installer identity, optionally rotating the host key.
key host key_mode:
    modules/deployment/scripts/usb/prepare-key.py "$@"

# Capture encrypted state for an installer; optionally close graphical apps.
state host output *args:
    bash modules/deployment/scripts/usb/capture-state.sh "$@"

# Build an offline ISO from prepared identity payloads; optionally --state ARCHIVE.age.
iso host *args:
    modules/deployment/scripts/usb/build-iso.sh "$@"

# Interactively select or explicitly provide a USB drive to write.
write image device="":
    modules/deployment/scripts/usb/write-usb.sh "$@"
