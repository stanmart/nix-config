# Additional home manager configuration for work machine
{ config, pkgs, lib, ... }:

{
  home.homeDirectory = "/Users/stanmart";

  # Extra packages for work machine
  home.packages = with pkgs; [
    # Dev tools
    asciinema_3
    cloc
    micromamba
    tlrc

    # Editors
    neovim

    # QC-specific
    awscli2
    jfrog-cli

    # Misc
    age
    btop
    cloudflared
    gnupg
    hcloud
    pandoc
    sqlite
    typst

    # Home manager
    home-manager
  ];

  programs.git = {
    settings = {
      user.email = lib.mkForce "martin.stancsics@quantco.com";
      credential.helper = lib.mkForce "cache --timeout=3600";
      user.signingkey = lib.mkForce "4C93F642AD2E65E6!";
    };
  };

  home.sessionPath = lib.mkBefore [
    "$HOME/.pixi/bin"
    "$HOME/.cargo/bin"
  ];

  home.sessionVariables = {
    SCIKIT_LEARN_DATA = "~/.datasets/scikit-learn";
    LIBSVMDATA_HOME = "~/.datasets/libsvm";
    CLAUDE_CODE_USE_BEDROCK = "1";
    AWS_CONFIG_FILE = "/Users/stanmart/.claude/aws.config";
    AWS_PROFILE = "stanmart";
    AWS_REGION = "eu-central-1";
  };

  programs.zsh.shellAliases = {
    clip = "pbcopy";
    git-yk = "git -c user.signingkey='F008E648EEF97446!'";  # yubikey commit signing
    claude-aws = "qc-claude-login && claude";
  };

  programs.zsh.initContent = lib.mkAfter ''
    if [ -f ~/.config/secrets/env ]; then
      source ~/.config/secrets/env
    fi
  '';

  # Homebrew packages (auto-synced on every home-manager switch)
  home.file."Brewfile".source = ./assets/Brewfile;

  home.activation.brewBundle = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    /opt/homebrew/bin/brew bundle --file ~/Brewfile --cleanup
  '';

  # ~/.claude/settings.json is not a symlink so the Claude Code UI can write to it
  # (model selection, etc.), but we merge our managed keys (awsAuthRefresh, sandbox,
  # permissions) into it on every activation.
  home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/.claude/settings.json"
    $DRY_RUN_CMD mkdir -p "$HOME/.claude"
    [ -f "$settings" ] || $DRY_RUN_CMD ${pkgs.coreutils}/bin/tee "$settings" <<<'{}' >/dev/null
    $DRY_RUN_CMD ${pkgs.jq}/bin/jq -s '.[0] + .[1]' \
      "$settings" ${./assets/claude-settings-managed.json} \
      > "$settings.tmp"
    $DRY_RUN_CMD mv "$settings.tmp" "$settings"
  '';

  # Additional dotfiles
  home.file.".claude/aws.config".source = ./assets/aws-config;
  xdg.configFile."ghostty/config".source = ./assets/ghostty-config;
  xdg.configFile."upterm/config.yaml".source = ./assets/upterm-config.yaml;
}
