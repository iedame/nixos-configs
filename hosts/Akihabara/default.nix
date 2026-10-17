{ pkgs, ... }:

{
  # NixOS under WSL on the gaming laptop (Windows 11). Only the command-line
  # side lives here; Windows keeps the games, the desktop apps and the
  # hardware, Tailscale included (see README.md).
  wsl = {
    enable = true;
    defaultUser = "haoji";
    # GPU acceleration (OpenGL, CUDA) through the Windows NVIDIA driver
    useWindowsDriver = true;
    # SSH_AUTH_SOCK reaches the Windows SSH agent, which 1Password provides:
    # SSH and commit signing use the keys there (modules/home-manager/ssh.nix
    # and git.nix)
    ssh-agent.enable = true;
  };

  # WSL can start the user's systemd manager (user@1000) while its cgroup is
  # still busy ("Failed to spawn executor: Device or resource busy"), and it
  # gives up. Without it no user service runs, the SSH agent bridge above
  # included: ssh then has no keys. Try again instead.
  systemd.services."user@".serviceConfig = {
    Restart = "on-failure";
    RestartSec = "2s";
  };

  networking.hostName = "Akihabara";

  custom.nix-core.enable = true;
  custom.locale.enable = true;

  users.users.haoji = {
    description = "Rafael Ieda";
    shell = pkgs.zsh;
  };

  # System zsh only sets up /etc/zshrc and the Nix environment; the
  # interactive config lives in home-manager (users/haoji/default.nix)
  programs.zsh = {
    enable = true;
    # Don't load NixOS's default prompt theme; oh-my-zsh sets the prompt
    promptInit = "";
  };

  # The release of the NixOS-WSL image it was installed from (2605.x)
  system.stateVersion = "26.05";
}
