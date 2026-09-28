# llama.cpp

This module lets a general-purpose graphical machine provide local llama.cpp inference without permanently reserving its GPU and memory. It supplies an on-demand proxy server for the inference host and a `llama-client` OpenCode wrapper for machines that use it remotely.

## Server

`llamaCpp.server.enable` starts a lightweight proxy on port 11434, but does not start `llama-server` until a request arrives. Before serving a remote request, the proxy warns and logs out every graphical user so that inference can take exclusive use of the machine's resources. Requests originating on the inference host do not log out local users.

The proxy starts `llama-server` with CUDA support from the unstable package set, forwards the request once the model is ready, and stops the model server after five minutes without activity. A systemd sleep inhibitor keeps the host awake while inference is running.

## Client

`llamaCpp.client.enable` installs `llama-client`, a wrapper around OpenCode. On hosts other than `white-tower`, the wrapper:

1. Sends a Wake-on-LAN request for `white-tower` through the `unifi` SSH host.
2. Waits for the proxy and model server to become ready.
3. Adds the proxy's OpenAI-compatible `/v1` endpoint to OpenCode's `llama.cpp` provider.
4. Runs OpenCode with all remaining arguments.

On `white-tower`, the wrapper connects to the local proxy without sending Wake-on-LAN. The proxy URL, readiness timeout, and Wake-on-LAN command details can be overridden with the `LLAMA_PROXY_*`, `LLAMA_WAIT_TIMEOUT`, and `LLAMA_WOL_*` environment variables defined in `llama-client.py`.

## Requirements

The server host must provide sufficient memory and an NVIDIA GPU supported by the unstable llama.cpp package. Model downloads require outbound access to Hugging Face. Remote clients must be able to resolve `white-tower`, reach TCP port 11434, and SSH to the `unifi` host that sends the magic packet.

## Persistence

Downloaded models and Hugging Face cache data persist under `/var/lib/llama-cpp`.

## Troubleshooting

Inspect `llama-cpp-proxy.service`; `llama-server` runs as its child. Probe `http://127.0.0.1:11434/_status` to distinguish proxy failures from the internal server on port 18080. Run `llama-client` without `--quiet` to see Wake-on-LAN and startup stages.
