# llama.cpp

The llama.cpp module runs local model inference and a small proxy service using the unstable package set.

## Requirements

The host must provide sufficient CPU, memory, and optional accelerator support for the selected model workload. Model downloads also require outbound access to the configured model source.

## Persistence

The module persists `/var/lib/llama-cpp`, including downloaded model and Hugging Face cache data, through `rootFs.persistDirectories`.

## Troubleshooting

Inspect `llama-cpp-proxy.service`; the `llama-server` process runs as its child rather than as a separate unit. Check `/var/lib/llama-cpp` and `/var/lib/llama-cpp/hf-cache` for model and cache state. Probe `http://127.0.0.1:11434/_status` to distinguish proxy failures from the internal server on `127.0.0.1:18080`.
