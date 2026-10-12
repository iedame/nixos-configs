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

    # Administration, locally or over SSH; the key that may log in is set
    # by modules/nixos/ssh-server.nix
    haoji = {
      isNormalUser = true;
      description = "Rafael Ieda";
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
    };
  };
}
