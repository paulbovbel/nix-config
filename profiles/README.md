# Profiles

Profiles combine system behavior with a user's Home Manager environment. Select them through NixOS options in each host's `configuration.nix`:

```nix
userProfiles.pbovbel = ["work" "gaming"];
```

## Available profiles

The generated profile reference lists each role's purpose and supported users from the registry in `default.nix`. Role documentation lives in each profile's README.

The registry in `profiles/default.nix` defines supported users, inheritance, system modules, and documentation titles. Selections use a per-user enum: unknown users, unsupported profiles, and misspellings fail option validation. Selected users must also have their account enabled. Common modules are shared implementation, not a selectable profile.

## Composition

`profiles/module.nix` statically imports the registered system modules and computes effective `systemProfiles` from user selections and inheritance. Each system profile gates its settings on that result. It supplies Home Manager imports in the separate user evaluation. System settings affect the whole machine, even when only one user selects the profile; Home Manager settings remain user-specific.

Gaming and work inherit the graphical baseline; graphical and headless share common system behavior. You do not need to select those baselines separately. With no selections, profile-provided system settings are disabled.

Home Manager receives the explicitly selected names through `profiles.selected`. Inherited profiles are not added to that list. Modules can use it to adapt to combinations, such as disabling gaming autostart when work is selected.

## Placement

- Host hardware, machine policy, and service enablement belong in `hosts/<host>/`.
- Shared role behavior belongs in `profiles/<profile>/system.nix`.
- User-specific environments belong in `profiles/<profile>/home/<user>.nix`.
- Reusable NixOS services belong in `modules/`.

When adding a selectable profile, update the registry, provide its system and user modules, and write its README. `profiles/documentation.nix` derives role pages from the registry. Keep NixOS imports static; condition settings with `lib.mkIf` instead of selecting imports from `config`.
