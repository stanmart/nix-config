# Common Home Manager configuration for stanmart user
# Shared across all hosts
{ config, pkgs, ... }:

{
  # Home Manager needs this information
  home.username = "stanmart";
  home.homeDirectory = "/home/stanmart";
  home.stateVersion = "24.05";

  # Common packages
  home.packages = with pkgs; [
    bat
    fzf
    fd
    ripgrep
    delta
    pixi
    uv
    vim
    micro
    htop
    tmux
    fastfetch
    wget
  ];

  # Environment variables
  home.sessionVariables = {
    EDITOR = "micro";
    LESS = "-iR";
  };

  # Direnv
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # Basic zsh configuration (can be overridden by oh-my-zsh module)
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;

    shellAliases = {
      cat = "bat -pp";
      ls = "ls --color=auto";
      ll = "ls -lah";
    };
  };

  # Git configuration
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Martin Stancsics";
        email = "martin.stancsics@gmail.com";
      };
      pull.rebase = true;
      core.autocrlf = "input";
    };
  };

  # Delta (git diff viewer)
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      syntax-theme = "Dracula";
    };
  };
}
