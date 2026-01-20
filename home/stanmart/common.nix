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
    # Shell / workflow
    bat
    dust
    eza
    fastfetch
    fd
    fzf
    htop
    htop
    jq
    ripgrep
    sd
    tree
    wget
    yq

    # Editors
    vim
    nano
    micro

    # Networking
    iperf3
    nmap
    rclone
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

  # Basic zsh configuration (can be overridden by other shell module)
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
      set -g default-terminal "tmux-256color"
      set -as terminal-features ",xterm-ghostty:RGB"
      set -as terminal-features ",tmux-256color:RGB"
    '';
  };

  # Git configuration
  programs.git = {
    enable = true;
    lfs.enable = true;

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

  # SSH
  programs.ssh = {
    enable = true;  # ensures ~/.ssh exists with sane perms
    enableDefaultConfig = false;  # we set our own defaults

    # Top-of-file raw additions — safe when missing and simple
    extraConfig = ''
      # Allow optional per-host overrides dropped by OrbStack (ignored if missing)
      Include ~/.orbstack/ssh/config
    '';

    # Structured host blocks (clean, declarative)
    matchBlocks = {
      # Global defaults
      "*" = {
        extraOptions = {
          SetEnv = "TERM=xterm-256color";
        };
      };

      csiganas = {
        user = "martin";
      };

      router = {
        hostname = "192.168.8.1";
        user = "admin";
        extraOptions = {
          HostkeyAlgorithms = "+ssh-rsa";
        };
      };

      "tiny-vm.akita-chicken.ts.net tiny-vm" = {
        hostname = "tiny-vm.akita-chicken.ts.net";
        user = "stanmart";
        extraOptions = {
          StrictHostKeyChecking = "no";
          UserKnownHostsFile = "/dev/null";
          GlobalKnownHostsFile = "/dev/null";
        };
      };
    };
  };

  # GPG
  programs.gpg = {
    enable = true;
    # optional: settings that are safe everywhere
    settings = {
      "keyid-format" = "0xlong";
      "with-fingerprint" = true;
      "use-agent" = true;
      keyserver = "hkps://keys.openpgp.org";
      "default-key" = "F008E648EEF97446";
    };
  };

  services.gpg-agent = {
    enable = true;

    # caches (seconds)
    defaultCacheTtl = 3600;      # 1h
    maxCacheTtl = 86400;         # 24h

    enableSshSupport = false;

    # pick pinentry per OS:
    pinentry.package =
      if pkgs.stdenv.isDarwin then pkgs.pinentry_mac else pkgs.pinentry-curses;
  };
}
