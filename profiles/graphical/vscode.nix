{
  unstablePkgs,
  vscode-workspace-populator,
  ...
}: let
  workspacePopulatorPackage = builtins.fromJSON (builtins.readFile "${vscode-workspace-populator}/package.json");
  inherit (workspacePopulatorPackage) name publisher version;
  uniqueId = "${publisher}.${name}";

  workspacePopulatorExtension = unstablePkgs.vscode-utils.buildVscodeExtension {
    pname = name;
    inherit version;
    sourceRoot = "${name}-${version}";
    vscodeExtPublisher = publisher;
    vscodeExtName = name;
    vscodeExtUniqueId = uniqueId;
    src = unstablePkgs.buildNpmPackage {
      pname = name;
      inherit version;
      src = vscode-workspace-populator;
      npmDepsHash = "sha256-ZXwk0OfJV0GcqUMV8iDYRy8DGGM7DYWu65cEHcjOo78=";
      npmBuildScript = "compile";
      installPhase = ''
        mkdir -p "$out"
        cp -r package.json README.md out "$out/"
      '';
    };
  };

  vscodeExtensions =
    (with unstablePkgs.vscode-marketplace; [
      github.codespaces
      github.copilot-chat
      github.vscode-github-actions
      github.vscode-pull-request-github
      jnoortheen.nix-ide
      kevinrose.vsc-python-indent
      ms-azuretools.vscode-containers
      ms-python.black-formatter
      ms-python.debugpy
      ms-python.python
      ms-python.vscode-pylance
      ms-python.vscode-python-envs
      ms-vscode-remote.remote-containers
      ms-vscode.cmake-tools
      ms-vscode.cpp-devtools
      ms-vscode.cpptools
      ms-vscode.cpptools-extension-pack
      ms-vscode.cpptools-themes
      redhat.vscode-yaml
      samuelcolvin.jinjahtml
      tomoki1207.pdf
      twxs.cmake
    ])
    ++ [
      workspacePopulatorExtension
    ];
in {
  programs.vscode = {
    enable = true;
    package = unstablePkgs.vscode;
    profiles.default = {
      extensions = vscodeExtensions;
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "application/json" = "code.desktop";
      "application/x-shellscript" = "code.desktop";
      "text/markdown" = "code.desktop";
      "text/plain" = "code.desktop";
      "text/x-c" = "code.desktop";
      "text/x-c++" = "code.desktop";
      "text/x-python" = "code.desktop";
    };
  };
}
