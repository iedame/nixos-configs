{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  cfg = config.custom.git;

  # 1Password's signer talks to the running 1Password app, which holds the
  # key. Under WSL, 1Password runs on Windows and its agent is reached
  # through SSH_AUTH_SOCK (wsl.ssh-agent), so plain ssh-keygen signs with
  # the key there.
  opSshSign =
    if pkgs.stdenv.hostPlatform.isDarwin then
      "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
    else if osConfig.wsl.ssh-agent.enable or false then
      lib.getExe' pkgs.openssh "ssh-keygen"
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
        # The same key that logs in to the hosts (lib/hosts.nix)
        default = (import ../../lib/hosts.nix).admin.key;
        defaultText = lib.literalExpression "(import ../../lib/hosts.nix).admin.key";
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
