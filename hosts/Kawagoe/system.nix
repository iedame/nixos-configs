{ inputs, pkgs, ... }:
{
  services.tailscale.enable = true;

  # nix-darwin's Tailscale module installs /etc/resolver/ts.net as a symlink
  # into /etc/static. tailscaled manages that directory itself and (since
  # 1.10x) refuses to write through a symlink leaving it, so it reports
  # "failed to set the DNS configuration ... path escapes from parent".
  # Let tailscaled own the file.
  environment.etc."resolver/ts.net".enable = false;

  # Matches darwinConfigurations.Kawagoe, so `darwin-rebuild` and `nh` find
  # the config without naming it. Sets HostName and LocalHostName
  # (Kawagoe.local); computerName is the friendly name in Finder and AirDrop.
  networking.hostName = "Kawagoe";
  networking.computerName = "Kawagoe";

  # Mac mini: come back on its own after a power cut
  power.restartAfterPowerFailure = true;
  # and never sleep: it runs linkding and reports to Uptime Kuma every
  # minute (default.nix), and asleep it does neither. macOS otherwise puts
  # it to sleep a minute after the display turns off, and the missing
  # reports look like a failure. The display still turns off.
  power.sleep.computer = "never";

  # macOS application firewall (per-app incoming connections), captured from
  # System Settings > Network > Firewall, plus stealth mode
  networking.applicationFirewall = {
    enable = true;
    # Built-in and downloaded signed apps may accept incoming connections
    allowSigned = true;
    allowSignedApp = true;
    # Don't answer pings or probes; sharing, AirDrop and Tailscale still work
    enableStealthMode = true;
    blockAllIncoming = false;
  };

  # sudo with a YubiKey touch instead of the password. Same origin as Aurora
  # (pam://yubi), so the same key registrations work on both machines.
  # "sufficient": without the key, the password prompt follows as usual.
  #
  # authfile points at a root-owned /etc file: with the default
  # ~/.config/Yubico/u2f_keys, pam_u2f switches to the user to read it, which
  # fails on macOS ("Unable to switch user"). It's also safer, since
  # user-level programs can't add their own keys to it.
  security.pam.services.sudo_local.text = ''
    auth       sufficient     ${pkgs.pam_u2f}/lib/security/pam_u2f.so origin=pam://yubi authfile=/etc/u2f_mappings cue
  '';

  # Registrations from `pamu2fcfg -o pam://yubi -i pam://yubi`, encrypted
  # with agenix (kawagoe/u2f_mappings.age in the private secrets repo) and
  # decrypted at activation to /etc/u2f_mappings (root-only). Edit with:
  #   cd ~/.config/nixos-secrets && agenix -e kawagoe/u2f_mappings.age -i ~/.ssh/agenix
  # then push there and run `nix flake update secrets` here.
  age.secrets.u2f_mappings = {
    file = "${inputs.secrets}/kawagoe/u2f_mappings.age";
    path = "/etc/u2f_mappings";
  };

  # pamu2fcfg, for registering keys
  environment.systemPackages = [ pkgs.pam_u2f ];
}
