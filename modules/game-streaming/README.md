# Game Streaming

Enable `gameStreaming.enable` in a host configuration to serve the shared
Sunshine application menu and enable sleep inhibition for Sunshine and Steam
Remote Play streams. Selecting the gaming user profile installs games and
launchers but does not enable this module.

`gameStreaming.encoder` defaults to automatic selection. Set it to `nvenc` for
an NVIDIA streaming host; this also enables CUDA support in Sunshine and
applies NVENC tuning in the Sunshine settings. `vaapi` and `software` are
available for other hosts.

The gaming profile enables gamemode and applies NVIDIA GPU optimisations when
the `nvidia` module is enabled. Further device-specific tuning can be set
through `services.sunshine.settings` and `programs.gamemode.settings` in the
host configuration.

## Sleep inhibition

User services inhibit idle sleep and suspend while streaming, polling every five
seconds:

- Steam Remote Play: reads the user's Steam streaming log and releases the
  inhibitor when the stream ends or Steam exits. Events from previous Steam
  runs and ordinary Game Recording do not activate it.
- Sunshine: reads connection events from the current Sunshine service invocation
  and counts connected Moonlight clients. The inhibitor is released when the
  last client disconnects or Sunshine stops, including crashes and restarts.

Simply leaving Steam or Sunshine running does not inhibit sleep.
