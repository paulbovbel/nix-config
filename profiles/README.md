# Profiles

Profiles combine system behavior with a user's Home Manager environment. Select them through NixOS options in each host's `configuration.nix`:

```nix
userProfiles.pbovbel = {
  profiles = ["work" "gaming"];
  shell = "hyprland";
};
```

Each user entry is an attribute set containing `profiles` (default `[]`) and
`shell` (default `"gnome"`). Shell choices are `"gnome"` and `"hyprland"`
(Caelestia), and apply when the selected profiles include the graphical baseline.
Selecting Hyprland requires a graphical profile. Users may choose different
shells on the same host.

Child status is shared account metadata under `accounts.<user>.isKid`; it defaults
to true for `abovbel` and false for adult accounts:

```nix
userProfiles.abovbel.profiles = ["gaming"];
```

Unless `tailnet.tags` is explicitly configured, any selected child account makes the entire machine a restricted
`tag:kids-device`; otherwise selected adults use `tag:adult-device`. Empty
profile selections contribute neither system behavior nor a tailnet role.

## Available profiles

The generated profile reference lists each role's purpose and supported users from the registry in `default.nix`. Role documentation lives in each profile's README.

The registry in `profiles/default.nix` defines supported users, inheritance, system modules, and documentation titles. The `profiles` list uses a per-user enum: unknown users, unsupported profiles, and misspellings fail option validation. Invalid shell names also fail validation. Selected users must also have their account enabled. Common modules are shared implementation, not a selectable profile.

## Composition

`profiles/module.nix` statically imports the registered system modules and computes effective `systemProfiles` from user selections and inheritance. Each system profile gates its settings on that result. It supplies Home Manager imports in the separate user evaluation. System settings affect the whole machine, even when only one user selects the profile; Home Manager settings remain user-specific.

Gaming and work inherit graphical, which inherits the base system and command-line baseline. Select base directly for servers and command-line environments. You do not need to select inherited baselines separately. With no selections, profile-provided system settings are disabled.

Home Manager receives the selected names and all inherited profiles through `profiles.selected`, with duplicates removed. For example, setting `userProfiles.pbovbel.profiles = ["work" "gaming"]` produces `["work" "gaming" "graphical" "base"]`. Modules can use it to adapt to combinations, such as disabling gaming autostart when work is selected. See the [graphical guide](graphical/README.md) for per-user shells and login sessions.

## Placement

- Host hardware, machine policy, and service enablement belong in `hosts/<host>/`.
- Shared role behavior belongs in `profiles/<profile>/system.nix`.
- User-specific environments belong in `profiles/<profile>/home/<user>.nix`.
- Reusable NixOS services belong in `modules/`.

When adding a selectable profile, update the registry, provide its system and user modules, and write its README. `profiles/documentation.nix` derives role pages from the registry. Keep NixOS imports static; condition settings with `lib.mkIf` instead of selecting imports from `config`.
