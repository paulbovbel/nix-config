# NVIDIA

The NVIDIA module configures the driver, suspend support, video acceleration, and optional PRIME render offload.

## Driver

`nvidia.open` selects open kernel modules. `nvidia.bleedingEdge` selects the unstable driver branch when the production branch is insufficient.

## PRIME Hybrid Graphics

`nvidia.prime.enable` configures a laptop with integrated and discrete GPUs. Set the bus ID for the integrated Intel or AMD GPU and for the NVIDIA GPU. Offload mode keeps the discrete GPU available on demand, and `enableOffloadCmd` installs the `nvidia-offload` launcher.

## Requirements

The selected kernel must be compatible with the driver.

## Troubleshooting

Use `nvidia-smi` and `journalctl -k` to check driver loading. Resume problems are reported by `nvidia-suspend.service`, `nvidia-resume.service`, or `nvidia-hibernate.service`; PRIME failures usually indicate incorrect `nvidia.prime.*BusId` values or offload settings.
