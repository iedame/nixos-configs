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
      # The shared folder with the games account, below
      "games"
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

  # A second desktop account for games and emulators that aren't trusted
  # with my files: no administrator rights, no SSH (only my key is
  # authorised, and only for haoji), no home-manager. Its password is set
  # on the machine with `passwd games`; it logs in from SDDM or through
  # "Switch user". Its home, like mine, is closed to other accounts.
  users.users.games = {
    isNormalUser = true;
    description = "Games";
    extraGroups = [ "games" ];
  };
  users.groups.games = { };

  systemd.tmpfiles.rules = [
    # A folder on the game drive for both accounts (ROMs, emulator keys and
    # firmware, installers): group games, setgid so what either account
    # puts there stays in the group, closed to everyone else
    "d /mnt/storage/games 2770 games games -"
    # My folder on the game drive was readable by every account; closed
    # like my home, so the games account can't look into it
    "z /mnt/storage/home/haoji 0700 haoji users -"
  ];

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
