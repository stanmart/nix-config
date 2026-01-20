# Nix module for configuring Git with GPG signing and GitHub SSH URL rewriting
# Only makes sense if the machine has GPG and SSH keys properly set up.
{ config, pkgs, lib, ... }:

{
  # Git signing with GPG
  programs.git = {
    signing = {
      signByDefault = true;
      key = null; # Uses default GPG key
    };
    
    # Rewrite GitHub URLs to use SSH (requires proper SSH key setup)
    settings = {
      "url \"git@github.com:\"" = {
        insteadOf = [
          "git@github.com:"
          "http://github.com/"
          "https://github.com/"
        ];
      };
    };
  };
}