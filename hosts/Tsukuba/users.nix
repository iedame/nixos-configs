{ ... }:

{
  # Passwords are set on the machine with `passwd`, not here.
  users.users = {
    # Uses the laptop day to day; no administrator rights
    yuki = {
      isNormalUser = true;
      description = "Yuki";
      extraGroups = [ "networkmanager" ];
    };

    # Administration, locally or over SSH
    haoji = {
      isNormalUser = true;
      description = "Rafael Ieda";
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      # 1Password SSH key (SHA256:u9tymbo3…), the same one that signs commits
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIo2Gq92qOW6e/+8g8R0ob+LZvmrZ6DjUj3V48HYrK98"
      ];
    };
  };
}
