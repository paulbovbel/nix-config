{
  config,
  lib,
  masterPkgs,
  vscode-workspace-populator,
  ...
}: let
  workspacePopulatorPackage = builtins.fromJSON (builtins.readFile "${vscode-workspace-populator}/package.json");
  inherit (workspacePopulatorPackage) name publisher version;
  uniqueId = "${publisher}.${name}";

  workspacePopulatorExtension = masterPkgs.vscode-utils.buildVscodeExtension {
    pname = name;
    inherit version;
    sourceRoot = "${name}-${version}";
    vscodeExtPublisher = publisher;
    vscodeExtName = name;
    vscodeExtUniqueId = uniqueId;
    src = masterPkgs.buildNpmPackage {
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

  vscodePackage = masterPkgs.vscode-with-extensions.override {
    inherit (masterPkgs) vscode;
    vscodeExtensions = with masterPkgs.vscode-marketplace; [
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
      workspacePopulatorExtension
    ];
  };
in {
  home.file.".local/share/applications/code.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Visual Studio Code
    GenericName=Text Editor
    Comment=Code Editing. Redefined.
    Exec=${vscodePackage}/bin/code --reuse-window %F
    Icon=vscode
    Terminal=false
    StartupNotify=true
    StartupWMClass=Code
    Categories=Development;IDE;TextEditor;
    MimeType=application/json;application/x-shellscript;text/markdown;text/plain;text/x-c;text/x-c++;text/x-python;
  '';

  dconf.settings."org/gnome/shell".favorite-apps = lib.mkAfter [
    "code.desktop"
  ];

  home.packages = [
    vscodePackage
  ];

  xdg.configFile = {
    "Code/User/settings.json".source = lib.mkForce (
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/users/${config.home.username}/vscode-settings.json"
    );

    "Code/User/keybindings.json".source = lib.mkForce (
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/users/${config.home.username}/vscode-keybindings.json"
    );
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
