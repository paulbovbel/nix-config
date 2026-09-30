{
  config,
  lib,
  options,
  pkgs,
  repositoryUrl,
  revision,
  sourceRevision,
  sourceRoot,
}: let
  modulesRoot = sourceRoot + "/modules";
  modulesRootString = toString modulesRoot;
  sourceRootString = toString sourceRoot;
  moduleEntries = builtins.readDir modulesRoot;
  discoveredModuleNames = builtins.filter (name:
    moduleEntries.${name}
    == "directory"
    && builtins.pathExists (modulesRoot + "/${name}/default.nix")) (builtins.attrNames moduleEntries);
  moduleMetadataByName = config.moduleDocumentation;
  metadataNames = builtins.attrNames moduleMetadataByName;
  missingMetadata = lib.subtractLists metadataNames discoveredModuleNames;
  unknownMetadata = lib.subtractLists discoveredModuleNames metadataNames;
  moduleNames = assert lib.assertMsg (missingMetadata == []) "Modules missing documentation metadata: ${lib.concatStringsSep ", " missingMetadata}";
  assert lib.assertMsg (unknownMetadata == []) "Documentation metadata references unknown modules: ${lib.concatStringsSep ", " unknownMetadata}"; metadataNames;
  metadataByName = moduleMetadataByName;

  isModuleDeclaration = declaration: let
    path = toString declaration;
  in
    path == modulesRootString || lib.hasPrefix "${modulesRootString}/" path;

  mkOptionsDoc = declarationFilter:
    pkgs.nixosOptionsDoc {
      inherit options;
      transformOptions = option: let
        declarations = builtins.filter declarationFilter option.declarations;
      in
        option
        // {
          visible =
            if declarations == []
            then false
            else option.visible;
          declarations =
            map (declaration: let
              path = lib.removePrefix "${sourceRootString}/" (toString declaration);
            in {
              name = path;
              url = "${repositoryUrl}/blob/${sourceRevision}/${path}";
            })
            declarations;
        };
    };

  allOptionsDoc = mkOptionsDoc isModuleDeclaration;
  allOptions = pkgs.runCommand "module-options.md" {} ''
    {
      printf '# Module Options\n\n'
      cat ${allOptionsDoc.optionsCommonMark}
    } > "$out"
  '';

  transformMarkdown = {
    dropTitle ? false,
    markdown,
    name,
  }:
    pkgs.runCommand "${name}.md" {nativeBuildInputs = [pkgs.python3];} ''
      python ${./scripts/transform_markdown.py} \
        ${lib.optionalString dropTitle "--drop-title"} \
        ${markdown} > "$out"
    '';

  prepareIntroduction = name: readme:
    transformMarkdown {
      dropTitle = true;
      markdown = pkgs.writeText "${name}-readme.md" (builtins.readFile readme);
      name = "${name}-introduction";
    };

  modulePages = lib.genAttrs moduleNames (name: let
    metadata = metadataByName.${name};
    readme = modulesRoot + "/${name}/README.md";
    hasIntroduction = builtins.pathExists readme;
  in {
    inherit (metadata) summary title;
    inherit hasIntroduction;
    heading = pkgs.writeText "${name}-title.md" (
      builtins.replaceStrings ["@moduleTitle@"] [metadata.title] (builtins.readFile ./templates/module.md)
    );
    introduction = lib.optional hasIntroduction (prepareIntroduction name readme);
  });

  moduleLinks =
    lib.concatMapStrings (name: ''
      - [${modulePages.${name}.title}](${name}.html) - ${modulePages.${name}.summary}
    '')
    moduleNames;
  sidebarModuleLinks =
    lib.concatMapStrings (name: ''
      <li><a href="${name}.html">${modulePages.${name}.title}</a></li>
    '')
    moduleNames;
  landingReadme =
    builtins.replaceStrings
    [
      "(modules/deployment/remote/README.md)"
      "(modules/deployment/usb/README.md)"
      "(modules/monitor/README.md)"
      "(modules/caddy/README.md)"
      "(modules/attic-cache/README.md)"
    ]
    [
      "(remote-deployment.html)"
      "(usb-deployment.html)"
      "(monitoring.html)"
      "(caddy.html)"
      "(attic-cache.html)"
    ]
    (builtins.readFile (sourceRoot + "/README.md"));
  index = pkgs.writeText "module-index.md" (
    landingReadme
    + "\n\n"
    + builtins.replaceStrings ["@modules@"] [moduleLinks] (builtins.readFile ./templates/index.md)
  );
  sidebar = builtins.replaceStrings ["@modules@"] [sidebarModuleLinks] (builtins.readFile ./assets/sidebar.html);
  pageTemplate = pkgs.writeText "page.html" (
    builtins.replaceStrings ["@sidebar@"] [sidebar] (builtins.readFile ./assets/page.html)
  );
  introductionHeading = pkgs.writeText "introduction-heading.md" (builtins.readFile ./templates/introduction.md);
  optionsHeading = pkgs.writeText "options-heading.md" (builtins.readFile ./templates/options.md);
  guides = map (guide:
    guide
    // {
      input = pkgs.writeText "${guide.name}.md" (
        builtins.replaceStrings guide.linkSources guide.linkTargets (
          builtins.readFile (sourceRoot + "/${guide.source}")
        )
      );
      output = "${guide.name}.html";
    }) [
    {
      name = "remote-deployment";
      title = "Remote deployment";
      source = "modules/deployment/remote/README.md";
      linkSources = ["(../usb/README.md)"];
      linkTargets = ["(usb-deployment.html)"];
    }
    {
      name = "usb-deployment";
      title = "USB deployment";
      source = "modules/deployment/usb/README.md";
      linkSources = ["(../remote/README.md)"];
      linkTargets = ["(remote-deployment.html)"];
    }
    {
      name = "monitoring";
      title = "Grafana dashboards";
      source = "modules/monitor/README.md";
      linkSources = [];
      linkTargets = [];
    }
  ];

  renderPage = {
    title,
    inputs,
    output,
    rawInputs ? [],
  }: ''
    pandoc \
      --from commonmark_x \
      --to html5 \
      --standalone \
      --template ${pageTemplate} \
      --metadata ${lib.escapeShellArg "pagetitle=${title}"} \
      --metadata lang=en \
      --metadata ${lib.escapeShellArg "repositoryUrl=${repositoryUrl}"} \
      --metadata ${lib.escapeShellArg "revision=${revision}"} \
      --output "$out/${output}" \
      ${lib.escapeShellArgs (map toString inputs)} \
      ${lib.concatMapStringsSep " " (input: ''"${input}"'') rawInputs}
  '';
in rec {
  module-docs =
    pkgs.runCommand "module-docs" {
      nativeBuildInputs = [pkgs.nixos-render-docs pkgs.pandoc pkgs.python3];
    } ''
      mkdir -p "$out"
      options_dir="$TMPDIR/module-options"
      mkdir -p "$options_dir"
      python ${./scripts/split_options.py} \
        ${allOptionsDoc.optionsJSON}/share/doc/nixos/options.json \
        "$options_dir" \
        ${lib.escapeShellArgs moduleNames}
      ${renderPage {
        title = "Nix-config modules";
        inputs = [index];
        output = "index.html";
      }}
      ${renderPage {
        title = "All module options";
        inputs = [allOptions];
        output = "all-options.html";
      }}
      ${lib.concatMapStringsSep "\n" (guide:
        renderPage {
          inherit (guide) output title;
          inputs = [guide.input];
        })
      guides}
      ${lib.concatMapStringsSep "\n" (name: ''
          nixos-render-docs -j "$NIX_BUILD_CORES" options commonmark \
            --manpage-urls ${pkgs.path + "/doc/manpage-urls.json"} \
            --revision ${lib.escapeShellArg revision} \
            "$options_dir/${name}.json" \
            "$options_dir/${name}-raw.md"
          python ${./scripts/transform_markdown.py} \
            "$options_dir/${name}-raw.md" \
            > "$options_dir/${name}.md"
          ${renderPage {
            title = modulePages.${name}.title;
            inputs =
              [modulePages.${name}.heading]
              ++ lib.optional modulePages.${name}.hasIntroduction introductionHeading
              ++ modulePages.${name}.introduction
              ++ [optionsHeading];
            rawInputs = ["$options_dir/${name}.md"];
            output = "${name}.html";
          }}
        '')
        moduleNames}
      cp ${./assets/style.css} "$out/style.css"
      cp ${./scripts/site.js} "$out/site.js"
      python ${./scripts/build_search.py} \
        "$out" \
        "$out/search.json" \
        ${lib.escapeShellArgs moduleNames}
    '';

  module-docs-check = pkgs.runCommand "module-docs-check" {nativeBuildInputs = [pkgs.python3];} ''
    PYTHONPATH=${./scripts} python ${./tests/test_docs.py}
    python ${./scripts/check_links.py} ${module-docs}
    touch "$out"
  '';
}
