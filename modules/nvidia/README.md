# NVIDIA

The NVIDIA module configures the pinned proprietary driver, open or closed kernel modules, suspend support, hardware video acceleration, and optional PRIME render offload.

## Requirements

Enable PRIME only on hybrid-graphics hosts and set the integrated and NVIDIA GPU bus IDs from `lspci`. The selected kernel must remain compatible with the pinned driver version.

## Troubleshooting

Use `nvidia-smi` and `journalctl -k` to check driver loading. Resume problems are reported by `nvidia-suspend.service`, `nvidia-resume.service`, or `nvidia-hibernate.service`; PRIME failures usually indicate incorrect `nvidia.prime.*BusId` values or offload settings.
