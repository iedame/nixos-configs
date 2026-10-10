{ pkgs, ... }:

{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.haoji = {
    isNormalUser = true;
    description = "Rafael Ieda";
    extraGroups = [
      "networkmanager"
      "wheel"
      "podman"
      "jellyfin"
      "immich"
      "syncthing"
      "i2c"
      "linkding"
    ];
    shell = pkgs.zsh;
    packages = with pkgs; [
      # keep-sorted start case=no
      kdePackages.kate
      kdePackages.kcalc
      kdePackages.kpat
      # keep-sorted end
    ];
  };

  # System zsh only sets up /etc/zshrc and the Nix environment; the
  # interactive config (oh-my-zsh, aliases, history) lives in home-manager
  # (modules/home-manager/zsh.nix, hosts/Aurora/users/haoji/default.nix)
  programs.zsh = {
    enable = true;
    # Don't load NixOS's default prompt theme; oh-my-zsh sets the prompt
    promptInit = "";
  };

  # YubiKey settings
  security.pam.u2f = {
    enable = true;
    settings = {
      interactive = true;
      cue = true;
      origin = "pam://yubi";
    };
  };

  security.pam.services = {
    login.u2fAuth = true;
    sudo.u2fAuth = true;
  };
}
