{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.zsh;
in
{
  options.custom.zsh = {
    enable = lib.mkEnableOption "Zsh configuration (oh-my-zsh, history, zoxide)";
    suggestionAliases = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable suggestion toggle aliases (suggestions_off/suggestions_on)";
    };
    darwinAliases = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Darwin-specific aliases (reloadDock)";
    };
    extraAliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional shell aliases, e.g. a host-specific `update`";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        programs.zsh = {
          enable = true;
          # EDITOR=nvim would otherwise switch zsh to vi keymap
          defaultKeymap = "emacs";
          enableCompletion = true;
          autosuggestion.enable = true;
          syntaxHighlighting.enable = true;
          history = {
            size = 10000;
            save = 10000;
            ignoreAllDups = true;
          };
          oh-my-zsh = {
            enable = true;
            plugins = [ "git" ];
            theme = "robbyrussell";
          };
          shellAliases = {
            ll = "ls -l";
            edit = "sudo -e";
            # Package diff between the two newest system generations.
            # GNU ls for -v (version sort: system-9 before system-10).
            update-diff = "${lib.getExe pkgs.nvd} diff $(${pkgs.coreutils}/bin/ls -d1v /nix/var/nix/profiles/system-*-link | tail -n 2)";
            push-config = "git -C ~/.config/nixos-configs push origin master && git -C ~/.config/nixos-configs push codeberg master";
          }
          // cfg.extraAliases;
        };

        # `z <dir>` jumping; replaces oh-my-zsh's z plugin
        programs.zoxide = {
          enable = true;
          enableZshIntegration = true;
        };
      }
      (lib.mkIf cfg.suggestionAliases {
        programs.zsh.shellAliases = {
          suggestions_off = "ZSH_AUTOSUGGEST_HISTORY_IGNORE=*";
          suggestions_on = "unset ZSH_AUTOSUGGEST_HISTORY_IGNORE";
        };
      })
      (lib.mkIf cfg.darwinAliases {
        programs.zsh.shellAliases = {
          reloadDock = ''
            defaults write com.apple.dock ResetLaunchPad -bool true;
            killall Dock;
            defaults write com.apple.dock ResetLaunchPad -bool false
          '';
        };
      })
    ]
  );
}
