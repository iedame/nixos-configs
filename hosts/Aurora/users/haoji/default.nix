{ config, pkgs, ... }:

{
  home.username = "haoji";
  home.homeDirectory = "/home/haoji";

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    # keep-sorted start case=no
    ncdu
    unzip
    # keep-sorted end
  ];

  custom.alacritty.enable = true;
  custom.nh.enable = true;
  custom.nix-index.enable = true;
  custom.ssh.enable = true;
  custom.shell-tools.enable = true;
  custom.claude-code.enable = true;
  custom.atuin.enable = true;
  custom.git = {
    enable = true;
    signing.enable = true;
  };

  custom.zsh = {
    enable = true;
    extraAliases = {
      # nh hides the activation's output, so say here whether the switch
      # installed a kernel that needs a reboot (custom.reboot-notice)
      update = "nh os switch -H Aurora && { needrestart || true; }";
    };
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
  };

  # Enable Ludusavi
  services.ludusavi = {
    enable = true;
    settings = {
      theme = "dark";
      backup = {
        path = "/backup-pool/documents/haoji/ludusavi/";
      };
      manifest = {
        url = "https://raw.githubusercontent.com/mtkennerly/ludusavi-manifest/master/data/manifest.yaml";
      };
      restore = {
        path = "/backup-pool/documents/haoji/ludusavi/";
      };
      roots = [
        {
          path = "/mnt/storage/home/haoji/.local/share/steam/";
          store = "steam";
        }
        {
          path = "/home/haoji/.local/share/Steam/";
          store = "steam";
        }
        {
          path = "/home/haoji/.config/heroic";
          store = "heroic";
        }
        {
          path = "/home/haoji/.local/share/lutris";
          store = "lutris";
        }
      ];
      customGames = [
        {
          name = "Trails in the Sky 1st Chapter Demo";
          files = [
            "/mnt/storage/home/haoji/.local/share/steam/steamapps/compatdata/3902570/pfx/drive_c/users/steamuser/Saved Games/Falcom/Trails in the Sky 1st Chapter/savedata/"
          ];
        }
      ];
    };
  };

  # This value determines the home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update home Manager without changing this value. See
  # the home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "25.05";
}
