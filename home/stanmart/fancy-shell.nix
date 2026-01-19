# Oh My Zsh configuration module for non-server machines
# Includes powerlevel10k theme, plugins, and custom settings
{ config, pkgs, lib, ... }:

let
  # fzf-tab isn't in core zsh; we fetch the plugin repo directly.
  fzf-tab = pkgs.fetchFromGitHub {
    owner = "Aloxaf";
    repo = "fzf-tab";
    rev = "cbdc58226a696688d08eae63d8e44f4b230fa3dd";
    sha256 = "sha256-ZekrZYQBGYQOTMojnJbQhelH4rOyzuPIP/Tu/6Tjwec=";
  };
in
{
  programs.zsh = {
    enable = true;

    # Let HM handle compinit; fzf-tab wants to be loaded after compinit
    # and before autosuggestions/syntax highlighting.
    enableCompletion = true;

    shellAliases = {
      cat = "bat -pp";
    };

    # Explicit plugin list (order matters!)
    plugins = [
      # Theme
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }

      # Completion UI — should be after compinit, before widget-wrapping plugins.
      {
        name = "fzf-tab";
        src = fzf-tab;
        file = "fzf-tab.plugin.zsh";
      }

      # "Widget wrappers" after fzf-tab
      {
        name = "zsh-autosuggestions";
        src = pkgs.zsh-autosuggestions;
        file = "share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh";
      }
      {
        name = "zsh-syntax-highlighting";
        src = pkgs.zsh-syntax-highlighting;
        file = "share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
      }
    ];

    initContent = lib.mkMerge [
      # Powerlevel10k instant prompt: keep it *very* early.
      (lib.mkBefore ''
        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi
      '')

      # Rest of the config
      ''
        # Your old OMZ settings
        HYPHEN_INSENSITIVE="true"
        HIST_STAMPS="yyyy-mm-dd"

        # FZF settings
        export FZF_DEFAULT_COMMAND="fd --type f"
        export FZF_CTRL_T_COMMAND="fd --type f"
        export FZF_ALT_C_COMMAND="fd --type d"
        export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=header,grid --line-range :300 {}'"

        # fzf-tab config
        zstyle ':completion:*:git-checkout:*' sort false
        zstyle ':completion:*:git-switch:*' sort false
        zstyle ':completion:*:descriptions' format '[%d]'
        zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
        zstyle ':completion:*' menu no
        zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'

        # Key binding
        bindkey '^U' backward-kill-line

        # p10k config managed by HM
        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

        # pixi niceties
        eval "$(pixi completion --shell zsh)"
      ''
    ];
  };

  # Additional packages needed for the setup
  home.packages = with pkgs; [
    zsh-powerlevel10k
    eza  # modern ls replacement used in fzf-tab preview
  ];

  # Enable fzf integration
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # Put your generated p10k config under HM control
  home.file.".p10k.zsh".source = ./p10k.zsh;
}
