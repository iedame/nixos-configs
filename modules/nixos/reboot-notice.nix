{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.reboot-notice;

  # Prints the kernel versions of the system it booted and of the current
  # one; exit status 1 if they differ
  needrestart = pkgs.writeShellApplication {
    name = "needrestart";
    text = ''
      parts="initrd kernel kernel-modules"
      # shellcheck disable=SC2086
      booted=$(cd /run/booted-system && readlink $parts)
      # shellcheck disable=SC2086
      current=$(cd /run/current-system && readlink $parts)
      running=$(uname -r)
      if [ "$booted" = "$current" ]; then
        echo "no reboot needed: running kernel $running"
      else
        echo "reboot needed: running kernel $running, installed $(ls /run/current-system/kernel-modules/lib/modules)"
        exit 1
      fi
    '';
  };
in
{
  # For hosts switched by hand (Aurora): a switch that installs a new
  # kernel says so at the end, since the new kernel only runs after a
  # reboot, and `needrestart` answers the same question at any time. The
  # Oracle hosts reboot by themselves instead (reboot-for-kernel.nix).
  options.custom.reboot-notice = {
    enable = lib.mkEnableOption "a notice when a switch installs a kernel that needs a reboot, and the `needrestart` command";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ needrestart ];

    system.activationScripts.reboot-notice = ''
      if [ -e /run/booted-system ]; then
        booted=$(cd /run/booted-system && readlink initrd kernel kernel-modules)
        new=$(cd "$systemConfig" && readlink initrd kernel kernel-modules)
        if [ "$booted" != "$new" ]; then
          printf '\033[1m==> Reboot required: this system has a new kernel\033[0m\n'
        fi
      fi
    '';
  };
}
