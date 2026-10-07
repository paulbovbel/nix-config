let
  registry = import ./default.nix;
  names = builtins.attrNames registry;
in
  [
    {
      name = "profiles";
      optionsModule = "profiles";
      title = "Selection and composition";
      category = "Profiles";
      source = "profiles/README.md";
      linkSources = map (name: "(${name}/README.md)") names;
      linkTargets = map (name: "(profile-${name}.html)") names;
      appendMarkdown =
        "\n\n## Profile availability\n\n| Profile | Purpose | Users |\n| --- | --- | --- |\n"
        + builtins.concatStringsSep "\n" (map (name: let
          profile = registry.${name};
          users = builtins.concatStringsSep ", " (map (user: "`${user}`") (builtins.attrNames profile.homeModule));
        in "| [${profile.title}](profile-${name}.html) | ${profile.summary} | ${users} |")
        names)
        + "\n";
    }
  ]
  ++ map (name: {
    name = "profile-${name}";
    inherit (registry.${name}) title;
    category = "Profiles";
    source = "profiles/${name}/README.md";
    linkSources = map (other: "(../${other}/README.md)") names;
    linkTargets = map (other: "(profile-${other}.html)") names;
  })
  names
