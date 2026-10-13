{
  config,
  pkgs,
  inputs,
  flake,
  ...
}:
{
  imports = [
    ./system.nix
    ./nixkeeper-start-runs.nix
    ./secrets.nix
    ./homebrew.nix
    ./defaults.nix
  ];

  environment.systemPackages = with pkgs; [
    # keep-sorted start case=no
    appcleaner
    bbedit
    coreutils
    element-desktop
    gh
    ghostscript
    git
    hydra-check
    img2pdf
    ncdu
    nix-update
    nixpkgs-review
    poppler-utils
    ripgrep
    syncthing-macos
    tailscale
    vim
    vlc-bin
    zapfast
    # keep-sorted end
  ];

  custom.fonts.enable = true;

  # Flakes, unfree, nixpkgs registry pin, weekly GC + store optimisation
  # (modules/darwin/nix-core.nix)
  custom.nix-core = {
    enable = true;
    # Compiling Intel Binaries
    extraPlatforms = [
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    # Nix's default (one build per core, each using every core) can start
    # dozens of compilers at once and make the Mac unusable during big
    # builds. Queue builds instead; downloads from the binary cache aren't
    # affected.
    build = {
      maxJobs = 2;
      cores = 4;
    };
  };

  nix.settings.sandbox = "relaxed";

  # Reports this Mac's health to an Uptime Kuma push monitor on one of the
  # Oracle servers, which alerts if the reports stop or one of these
  # background jobs ended in an error (modules/darwin/heartbeat.nix). The
  # monitor's push URL is an agenix secret (secrets.nix).
  custom.heartbeat = {
    enable = true;
    urlFile = config.age.secrets."heartbeat-url".path;
    agents = [
      "org.nix-community.home.linkding"
      "org.nix-community.home.linkding-background-tasks"
    ];
  };

  # nixkeeper's runs are started from Narita. Set this to true to do it
  # from here while that server is down (nixkeeper-start-runs.nix).
  custom.nixkeeper-start-runs.enable = false;

  # Compiling Linux Binaries
  nix.linux-builder.enable = false;

  system.primaryUser = "haoji";

  system.stateVersion = 6;

  system.configurationRevision = flake.rev or flake.dirtyRev or null;

  users.users.haoji.home = "/Users/haoji";

  nixpkgs.hostPlatform = "aarch64-darwin";

  # System zsh only sets up /etc/zshrc and the Nix environment; the
  # interactive config (oh-my-zsh, aliases, history) lives in home-manager
  # (modules/home-manager/zsh.nix, hosts/Kawagoe/users/haoji/zsh.nix)
  programs.zsh.enable = true;
}
