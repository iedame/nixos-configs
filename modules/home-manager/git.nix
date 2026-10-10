{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  cfg = config.custom.git;

  # 1Password's signer talks to the running 1Password app, which holds the key
  opSshSign =
    if pkgs.stdenv.hostPlatform.isDarwin then
      "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
    else
      lib.getExe' osConfig.programs._1password-gui.package "op-ssh-sign";
in
{
  options.custom.git = {
    enable = lib.mkEnableOption "Git configuration";
    userName = lib.mkOption {
      type = lib.types.str;
      default = "Rafael Ieda";
      description = "Commit author name";
    };
    userEmail = lib.mkOption {
      type = lib.types.str;
      default = "git@ieda.me";
      description = "Commit author email";
    };
    signing = {
      enable = lib.mkEnableOption "signing commits and tags with an SSH key held by 1Password";
      key = lib.mkOption {
        type = lib.types.str;
        # 1Password SSH key, also a GitHub login key
        # (SHA256:u9tymbo3MxmadJAyyJvRq4C+qerPciuRvMU9CMk1GTY)
        default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIo2Gq92qOW6e/+8g8R0ob+LZvmrZ6DjUj3V48HYrK98";
        description = "Public SSH key used for signing (the private half stays in 1Password)";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
      settings = {
        user = {
          name = cfg.userName;
          email = cfg.userEmail;
        };
        fetch.prune = true;
      };
      signing = lib.mkIf cfg.signing.enable {
        format = "ssh";
        key = cfg.signing.key;
        signByDefault = true;
        signer = opSshSign;
        # Lets `git log --show-signature` verify my own commits locally
        allowedSigners = "${cfg.userEmail} ${cfg.signing.key}";
      };
    };
  };
}
