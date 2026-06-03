{
  config,
  lib,
  pkgs,
  masterPkgs,
  ...
}: {
  imports = [
    ./base.nix
    ../common/graphical.nix
    ../common/gravatar.nix
  ];

  home.file.".local/share/backgrounds/pbovbel-tropicanair.jpg".source =
    ../../assets/wallpapers/pbovbel-tropicanair.jpg;
  dconf.settings = {
    "org/gnome/desktop/background" = {
      picture-uri = "file://${config.home.homeDirectory}/.local/share/backgrounds/pbovbel-tropicanair.jpg";
      picture-uri-dark = "file://${config.home.homeDirectory}/.local/share/backgrounds/pbovbel-tropicanair.jpg";
      picture-options = "zoom";
    };
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-timeout = 900;
      sleep-inactive-battery-timeout = 900;
    };
    "org/gnome/shell".favorite-apps = lib.mkAfter [
      "code.desktop"
    ];
  };

  bovbel.gravatarAvatar = {
    enable = true;
    hash = "c436d411a0ecc119476d704396a47d3e";
    fileName = "pbovbel-gravatar.jpg";
  };

  home.packages = [
    pkgs.python3
    pkgs.tail-tray
    pkgs.uv
    (masterPkgs.vscode-with-extensions.override {
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
      ];
    })
  ];

  xdg.configFile = {
    "Code/User/settings.json".text = builtins.toJSON {
      "files.trimTrailingWhitespace" = true;
      "files.insertFinalNewline" = true;
      "files.trimFinalNewlines" = true;
      "files.eol" = "\n";

      "editor.formatOnSave" = true;
      "editor.codeActionsOnSave" = {
        "source.fixAll" = "explicit";
      };

      "diffEditor.ignoreTrimWhitespace" = false;
      "git.autofetch" = true;
      "chat.tools.terminal.autoApprove" = {
        just = true;
      };

      "editor.renderWhitespace" = "selection";
      "editor.rulers" = [100];
      "editor.tabSize" = 2;
      "editor.detectIndentation" = true;

      "workbench.startupEditor" = "none";
      "telemetry.telemetryLevel" = "off";
    };

    "Code/User/keybindings.json".text = builtins.toJSON [
      {
        key = "ctrl+alt+shift+up";
        command = "editor.action.copyLinesUpAction";
        when = "editorTextFocus && !editorReadonly";
      }
      {
        key = "ctrl+alt+shift+down";
        command = "editor.action.copyLinesDownAction";
        when = "editorTextFocus && !editorReadonly";
      }
    ];

    "autostart/solaar.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Version=1.0
      Name=Solaar
      Exec=${pkgs.solaar}/bin/solaar --window=hide
      X-GNOME-Autostart-enabled=true
    '';

    "autostart/tail-tray.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Version=1.0
      Name=Tail Tray
      Exec=${pkgs.tail-tray}/bin/tail-tray
      X-GNOME-Autostart-enabled=true
    '';
  };
}
