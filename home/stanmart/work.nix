# Additional home manager configuration for work machine
{ config, pkgs, lib, ... }:

{
  home.homeDirectory = lib.mkForce "/Users/stanmart";

  # Extra packages for work machine
  home.packages = with pkgs; [
    # Dev tools
    asciinema_3
    tlrc
    cloc

    # Editors
    neovim

    # Misc
    age
    cloudflared
    gnupg
    hcloud
    sqlite
    typst
  ];

  programs.git = {
    settings = {
      user.email = lib.mkForce "martin.stancsics@quantco.com";
      credential.helper = lib.mkForce "cache --timeout=3600";
      user.signingkey = lib.mkForce "4C93F642AD2E65E6!";
    };
  };

  home.sessionPath = [
    "$HOME/.pixi/bin"
    "$HOME/.cargo/bin"
  ];

  home.sessionVariables = {
    SCIKIT_LEARN_DATA = "~/.datasets/scikit-learn";
    LIBSVMDATA_HOME = "~/.datasets/libsvm";
  };

  programs.zsh.shellAliases = {
    clip = "pbcopy";
    git-yk = "git -c user.signingkey='F008E648EEF97446!'";  # yubikey commit signing
    claude-login = "AWS_PROFILE=stanmart AWS_REGION=eu-central-1 aws sts get-caller-identity > /dev/null || aws sso login";
    claude-aws = "claude-login && claude";
  };

  programs.zsh.initContent = lib.mkAfter ''
    if [ -f ~/.config/secrets/env ]; then
      source ~/.config/secrets/env
    fi
  '';

  # Homebrew packages (not auto-installed, run `brew bundle --file ~/Brewfile` manually)
  home.file."Brewfile".source = ./assets/Brewfile;
}
