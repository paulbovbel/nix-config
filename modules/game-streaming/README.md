# Game Streaming

Enable `gameStreaming.enable` in a host configuration to serve the shared
Sunshine application menu. Selecting the gaming user profile installs games and
launchers but does not enable a streaming server.

`gameStreaming.encoder` defaults to automatic selection. Set it to `nvenc` for
an NVIDIA streaming host; this also enables CUDA support in Sunshine. `vaapi`
and `software` are available for other hosts.

Set device-specific tuning through `services.sunshine.settings` and
`programs.gamemode.settings.gpu` in the host configuration. The gaming profile
does not assume a GPU vendor or device index.
