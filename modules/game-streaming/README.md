# Game Streaming

Enable `gameStreaming.enable` in a host configuration to serve the shared
Sunshine application menu. Selecting the gaming user profile installs games and
launchers but does not enable a streaming server.

`gameStreaming.encoder` defaults to automatic selection. Set it to `nvenc` for
an NVIDIA streaming host; this also enables CUDA support in Sunshine and
applies NVENC tuning in the Sunshine settings. `vaapi` and `software` are
available for other hosts.

The gaming profile enables gamemode and applies NVIDIA GPU optimisations when
the `nvidia` module is enabled. Further device-specific tuning can be set
through `services.sunshine.settings` and `programs.gamemode.settings` in the
host configuration.
