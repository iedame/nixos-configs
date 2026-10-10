{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.shell-tools;
in
{
  options.custom.shell-tools = {
    enable = lib.mkEnableOption "shell tools (direnv + nix-direnv, fzf, bat, eza)";
  };

  config = lib.mkIf cfg.enable {
    # Loads a project's environment when you cd into it; `use flake` in an
    # .envrc enters its Nix dev shell, cached by nix-direnv so it's instant
    # after the first time
    programs.direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
      # Don't print the full list of changed variables on every cd
      config.global.hide_env_diff = true;
    };

    # Fuzzy finder: Ctrl-R history search, Ctrl-T file picker, Alt-C cd
    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    # `bat`: cat with syntax highlighting and paging
    programs.bat.enable = true;

    # `eza`: modern ls with git status and tree view (eza --tree). Its zsh
    # integration would replace ls/ll with eza aliases, so it's off and
    # plain ls keeps working as before
    programs.eza = {
      enable = true;
      enableZshIntegration = false;
      git = true;
    };
  };
}
