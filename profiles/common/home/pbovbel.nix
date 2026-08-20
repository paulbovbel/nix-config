{
  lib,
  pkgs,
  unstablePkgs,
  ...
}: let
  keys = import ../../../keys.nix;
  sshConfig = pkgs.writeText "pbovbel-ssh-config" ''
    IgnoreUnknown WarnWeakCrypto

    Include config.d/*

    Host github.com
      HostName ssh.github.com
      Port 443
      User git

    Host *
      IdentityFile ~/.ssh/id_rsa
      IdentitiesOnly yes

    Host unifi jetkvm*
      User root
      WarnWeakCrypto no

    # Send a WoL packet before connecting; the Match block is intentionally
    # empty because the exec predicate performs the knock as its side effect.
    Match host white-tower exec "ssh unifi 'BROADCAST=192.168.1.255 PORT=9 ./wol.sh 18:c0:4d:a9:3c:ae'"
  '';
in {
  imports = [
    ../home.nix
  ];

  home = {
    username = "pbovbel";
    homeDirectory = "/home/pbovbel";

    file.".ssh/id_rsa.pub".text = keys.pbovbel;
  };

  # Necessary to have ~/.ssh/config as a regular file - openssh in distrobox container wants it this way
  home.activation.writeSshConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    install -d -m 700 "$HOME/.ssh"
    rm -f "$HOME/.ssh/config"
    install -m 600 ${sshConfig} "$HOME/.ssh/config"
  '';

  home.packages = with pkgs; [
    nix-tree
    (pkgs.writeShellApplication {
      name = "llama-client";
      runtimeInputs = with pkgs; [
        (python3.withPackages (ps: [ps.aiohttp]))
      ];
      text = ''
        exec python ${./llama-client.py} "$@"
      '';
    })
  ];

  programs = {
    opencode = {
      enable = true;
      package = unstablePkgs.opencode;
      settings = {
        enabled_providers = ["openai" "llama.cpp"];
        model = "llama.cpp/qwen3.6";
        provider = {
          openai = {};
          "llama.cpp" = {
            npm = "@ai-sdk/openai-compatible";
            name = "Local LLM";
            options = {
              baseURL = "http://white-tower:11434/v1";
              stream = false;
            };
            models = {
              "qwen3.6" = {
                name = "Local Model";
                tool_call = true;
                options.toolParser = "auto";
              };
            };
          };
        };
        permission.external_directory."/nix/store/**" = "allow";
        mcp.nixos = {
          type = "local";
          command = ["${unstablePkgs.mcp-nixos}/bin/mcp-nixos"];
        };
        mcp.plex = {
          type = "remote";
          url = "http://media:3001/sse";
        };
      };
    };

    bash = {
      enable = true;
      initExtra = ''
        if [ -d "$HOME/.bashrc.d" ]; then
          for bashrc_fragment in "$HOME"/.bashrc.d/*; do
            if [ -f "$bashrc_fragment" ] && [ -r "$bashrc_fragment" ]; then
              . "$bashrc_fragment"
            fi
          done
          unset bashrc_fragment
        fi

        if [ -n "''${CONTAINER_ID:-}" ]; then
          PS1='\[\e[34m\][\u@'$CONTAINER_ID':\w]\$ \[\e[0m\]'
        fi
      '';
    };

    git = {
      enable = true;
      lfs.enable = true;
      settings = {
        alias = {
          bclean = ''!f() { git branch --merged ''${1-master} | grep -v " ''${1-master}$" | xargs -r git branch -d; }; f'';
          bdone = ''!f() { git checkout ''${1-master} && git up && git bclean ''${1-master}; }; f'';
          cm = "!git add -u && git commit -m";
          cmnew = "!git add -A && git commit -m";
          co = "checkout";
          cob = "checkout -b";
          cp = "cherry-pick -x";
          fixup = "!git add -u && git commit --amend";
          pushb = "push -u origin";
          rb = "rebase";
          st = "status";
        };
        core.editor = "nano";
        credential.helper = "cache";
        fetch.prune = true;
        pull.rebase = true;
        push = {
          default = "simple";
          followTags = true;
        };
        url."git@github.com:".insteadOf = [
          "https://github.com/"
          "git://github.com/"
        ];
        user = {
          email = "paul@bovbel.com";
          name = "Paul Bovbel";
        };
      };
    };
  };
}
