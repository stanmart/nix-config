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
    pixi
    uv
    vim
    micro
    htop
    fastfetch
    wget
    gcc
    gnumake
    rustup
  ];

  # Environment variables
  home.sessionVariables = {
    EDITOR = "micro";
    LESS = "-iR";
  };

  # PATH additions
  home.sessionPath = [
    "$HOME/.pixi/bin"
    "$HOME/.cargo/bin"
  ];

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
    
    shellAliases = {
      cat = "bat -pp";
      ls = "ls --color=auto";
      ll = "ls -lah";
    };
  };

  programs.tmux = {
    enable = true;

    clock24 = true;
    keyMode = "vi";
    historyLimit = 10000;

    extraConfig = ''
      set -g mouse on
      set -g status-keys vi
    '';
  };

  # Git configuration
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Martin Stancsics";
        email = "martin.stancsics@gmail.com";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      rerere.enabled = true;
      core = {
        autocrlf = "input";
        excludesFile = "~/.gitignore";
      };
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
      merge.conflictStyle = "zdiff3";
      grep.lineNumber = true;
      color.ui = "auto";
    };
  };

  # Github CLI
  programs.gh = {
    enable = true;
    gitCredentialHelper = {
      enable = true;
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
