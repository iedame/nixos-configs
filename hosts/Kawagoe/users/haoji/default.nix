{
  lib,
  osConfig,
  pkgs,
  ...
}:
{
  imports = [
    ./zsh.nix
  ];

  home.username = "haoji";
  home.homeDirectory = "/Users/haoji";

  # coreutils comes from the system profile
  home.packages = with pkgs; [
    # keep-sorted start case=no
    rsync
    # keep-sorted end
  ];

  # Target folder for system.defaults.screencapture.location; macOS falls
  # back to the Desktop if it doesn't exist
  home.activation.createScreenshotsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/Pictures/Screenshots"
  '';

  custom.alacritty.enable = true;
  custom.nh.enable = true;
  custom.nix-index.enable = true;
  custom.ssh.enable = true;
  custom.shell-tools.enable = true;
  custom.claude-code.enable = true;
  # Bookmark manager on http://localhost:9090 (modules/home-manager/darwin/linkding.nix)
  custom.linkding = {
    enable = true;
    # agenix secret, see ../../secrets.nix
    environmentFile = osConfig.age.secrets."linkding.env".path;
  };
  custom.git = {
    enable = true;
    signing.enable = true;
  };

  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

}
