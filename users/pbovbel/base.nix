{
  pkgs,
  unstablePkgs,
  ...
}: {
  imports = [
    ../common/base.nix
  ];

  home = {
    username = "pbovbel";
    homeDirectory = "/home/pbovbel";

    file.".ssh/id_rsa.pub".text = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC1WGjxe/6kJ2uHiI1R85VifWC2GeaEj98sAZIMLtFqgqY8zASg7in+We4oE/H1xBPf9AXHwM03rNTNQyVQ/w+YRacPAiRI8w6/tnx+ry/atxwZjFuGgYvzJockc1ar3zGSa3TWWUqe85TfwB6YjbQtSqqvGQ+BWI44+nsbKgGtFzyVyBBhdYmuBcVkNi9rCATRtto4rmBEs9RfHvWb+dLXMdUZbo4DsYZanMiucbWkrq4soHVZKJWGMqBmVRwVsO+pm9FyE3p1EaRh5afILCKi0X3X3jdJUrWIqqn7SiqaQCrx4uotpQef0S45eJhl2AqwpB66OnngMfhB4xaO+wgBEpjOheLLcfnFCH9WXEmD6r49om91K22+8j20Y93zNeDoYC6OYxe0flAzdsTbyfyx2lo2/TdNzYc5ruqgNbnhDnbeZJ2JLx3CbpixxGZJU9BhG2Pye+dpgnLTT48jEX5L/kWQMNkD50mpIEbFK8zLASH5g1q5bvw0NuTrpN8u2FqCmPEvpybFOTw1lV13I0l2fCdHSw3RNPA3QSP/GeGbOkx7yGWH2wJxJTGr1up2FBp7S6uCqU7MlVlrRbSzyKEmH5cTTFho+CnAhr1lQtlajCRTwm5UuoQYLFYkT/J+1lcXqU40H7jKYqRdwgVZ5CL6smJ/9IuZiJY2CA3rmcrPFQ== paul@bovbel.com";
    file.".ssh/config".text = ''
      Host *
        IdentityFile ~/.ssh/id_rsa
        IdentitiesOnly yes
    '';
  };

  home.packages = with pkgs; [
    unstablePkgs.opencode
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

  home.file.".config/opencode/opencode.json".source = (pkgs.formats.json {}).generate "opencode-config" {
    "$schema" = "https://opencode.ai/config.json";
    model = "llama.cpp/qwen3.6";
    provider = {
      llama-cpp = {
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
  };

  programs.git = {
    enable = true;
    settings = {
      alias = {
        cm = "!git add -u && git commit -m";
        cmnew = "!git add -A && git commit -m";
        fixup = "!git add -u && git commit --amend";
        pushb = "push -u origin";
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
}
