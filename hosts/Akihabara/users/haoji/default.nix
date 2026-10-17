{ pkgs, ... }:

{
  home.username = "haoji";
  home.homeDirectory = "/home/haoji";

  home.packages = with pkgs; [
    # keep-sorted start case=no
    ncdu
    unzip
    # keep-sorted end
  ];

  custom.nh.enable = true;
  custom.nix-index.enable = true;
  custom.ssh.enable = true;
  custom.shell-tools.enable = true;
  custom.claude-code.enable = true;
  custom.git = {
    enable = true;
    signing.enable = true;
  };

  custom.zsh = {
    enable = true;
    extraAliases = {
      update = "nh os switch -H Akihabara";
    };
  };

  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}
