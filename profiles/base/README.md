# Base

Shared system and command-line baseline for all profiles. Select it directly
for a server or command-line-only environment:

```nix
userProfiles.pbovbel.profiles = ["base"];
```

Provides shared boot, core services, monitoring, mail, Tailscale enrollment,
and each user's baseline Home Manager environment. Graphical inherits base;
gaming and work inherit graphical. Host configuration selects server workloads
and infrastructure tailnet tags.
