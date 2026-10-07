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
    path == modulesRootString || lib.hasPrefix "${modulesRootString}/" path || path == "${sourceRootString}/profiles/options.nix";

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

  moduleLinks =
    lib.concatMapStrings (name: ''
      - [${metadataByName.${name}.title}](${name}.html) - ${metadataByName.${name}.summary}
    '')
    moduleNames;
  normalizePage = page: let
    isModule = page.modulePage or false;
    hasSource = builtins.pathExists (sourceRoot + "/${page.source}");
    markdown = pkgs.writeText "${page.name}-readme.md" (
      builtins.replaceStrings (page.linkSources or []) (page.linkTargets or []) (
        builtins.readFile (sourceRoot + "/${page.source}") + (page.appendMarkdown or "")
      )
    );
    heading = pkgs.writeText "${page.name}-title.md" (
      builtins.replaceStrings ["@moduleTitle@"] [page.title] (builtins.readFile ./templates/module.md)
    );
  in
    page
    // {
      output = "${page.name}.html";
      inherit hasSource;
      inputs =
        (
          if isModule
          then
            [heading]
            ++ lib.optionals hasSource [
              introductionHeading
              (transformMarkdown {
                dropTitle = true;
                inherit markdown;
                name = "${page.name}-introduction";
              })
            ]
          else [markdown]
        )
        ++ lib.optional (page ? optionsModule) optionsHeading;
      rawInputs = lib.optional (page ? optionsModule) "$options_dir/${page.optionsModule}.md";
    };
  pages = map normalizePage (
    map (name: {
      inherit name;
      inherit (metadataByName.${name}) title category;
      optionsModule = name;
      source = "modules/${name}/README.md";
      modulePage = true;
    })
    moduleNames
    ++ import ../deployment/documentation.nix
    ++ import ../../profiles/documentation.nix
  );
  pageCategories = import ./categories.nix;
  optionPageNames = map (page: page.optionsModule) (builtins.filter (page: page ? optionsModule) pages);
  sidebarCategory = heading: category: ''
    <section>
      <${heading} class="${
      if heading == "h2"
      then "sidebar-heading"
      else "sidebar-subheading"
    }">${category}</${heading}>
      <ul class="module-list">
        ${lib.concatMapStrings (page: ''
        <li><a href="${page.output}">${page.title}</a></li>
      '')
      (builtins.filter (page: page.category == category) pages)}
      </ul>
    </section>
  '';
  sidebarLinks = assert lib.assertMsg (lib.all (page: builtins.elem page.category pageCategories) pages) "Every page must declare a known documentation category";
    sidebarCategory "h2" "Deployment"
    + sidebarCategory "h2" "Profiles"
    + ''
      <section>
        <h2 class="sidebar-heading">Modules</h2>
        ${lib.concatMapStrings (sidebarCategory "h3") (builtins.filter (category: !(builtins.elem category ["Deployment" "Profiles"])) pageCategories)}
      </section>
    '';
  readmePages = builtins.filter (page: page.hasSource) pages;
  landingReadme =
    builtins.replaceStrings
    (map (page: "(${page.source})") readmePages)
    (map (page: "(${page.output})") readmePages)
    (builtins.readFile (sourceRoot + "/README.md"));
  index = pkgs.writeText "module-index.md" (
    landingReadme
    + "\n\n"
    + builtins.replaceStrings ["@modules@"] [moduleLinks] (builtins.readFile ./templates/index.md)
  );
  sidebar = builtins.replaceStrings ["@pages@"] [sidebarLinks] (builtins.readFile ./assets/sidebar.html);
  pageTemplate = pkgs.writeText "page.html" (
    builtins.replaceStrings ["@sidebar@"] [sidebar] (builtins.readFile ./assets/page.html)
  );
  introductionHeading = pkgs.writeText "introduction-heading.md" (builtins.readFile ./templates/introduction.md);
  optionsHeading = pkgs.writeText "options-heading.md" (builtins.readFile ./templates/options.md);

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
        ${lib.escapeShellArgs optionPageNames}
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
      ${lib.concatMapStringsSep "\n" (page: let
          name = page.optionsModule or page.name;
          hasOptions = page ? optionsModule;
        in ''
          ${lib.optionalString hasOptions ''
            nixos-render-docs -j "$NIX_BUILD_CORES" options commonmark \
              --manpage-urls ${pkgs.path + "/doc/manpage-urls.json"} \
              --revision ${lib.escapeShellArg revision} \
              "$options_dir/${name}.json" \
              "$options_dir/${name}-raw.md"
            python ${./scripts/transform_markdown.py} \
              "$options_dir/${name}-raw.md" \
               > "$options_dir/${name}.md"
          ''}
          ${renderPage {
            inherit (page) title output;
            inherit (page) inputs rawInputs;
          }}
        '')
        pages}
      cp ${./assets/style.css} "$out/style.css"
      cp ${./scripts/site.js} "$out/site.js"
      python ${./scripts/build_search.py} \
        "$out" \
        "$out/search.json" \
        ${lib.escapeShellArgs optionPageNames}
    '';

  module-docs-check = pkgs.runCommand "module-docs-check" {nativeBuildInputs = [pkgs.python3];} ''
    PYTHONPATH=${./scripts} python ${./tests/test_docs.py}
    python ${./scripts/check_links.py} ${module-docs}
    touch "$out"
  '';
}
