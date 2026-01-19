{ config, pkgs, lib, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    shellAliases = {
      cat = "bat -pp";
    };

    # Explicit plugin list
    plugins = [
      # Autosuggestions
      {
        name = "zsh-autosuggestions";
        src = pkgs.zsh-autosuggestions;
        file = "share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh";
      }

      # Syntax highlighting (must be last)
      {
        name = "zsh-syntax-highlighting";
        src = pkgs.zsh-syntax-highlighting;
        file = "share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
      }
    ];

    # Initialize the prompt
    initContent = lib.mkBefore ''
      autoload -Uz colors && colors

      # user@host:/path $
      PROMPT='%F{cyan}%n@%m%f:%F{yellow}%~%f %# '
    '';
  };
}