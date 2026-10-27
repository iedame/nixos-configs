# Rules every host's configuration must keep, checked by evaluating each
# one (`nix flake check`, so on every pull request). Nothing is built, so
# it costs seconds. A failing rule fails the check with every broken rule
# and host listed.
#
# Exceptions are named here, each with its reason, so a host only leaves a
# rule on purpose.
{
  lib,
  pkgs,
  nixosConfigurations,
  darwinConfigurations,
}:
let
  # NixOS under WSL: a shell on the gaming laptop. Windows runs its
  # Tailscale, and it has no SSH server, heartbeat or Beszel agent.
  wsl = [ "Akihabara" ];

  # May open ports on every interface, not only Tailscale: the desktop at
  # home, behind the router, for Jellyfin, the *arr apps and Steam on the
  # LAN (hosts/Aurora/)
  lanPorts = [ "Aurora" ];

  # May accept SSH on every interface (custom.ssh-server.openToInternet):
  # only while a host converted from Ubuntu hasn't joined the tailnet yet
  # (hosts/Narita/README.md). Add it here in the same change, and remove
  # it with the setting.
  sshToInternet = [ ];

  rule = name: ok: lib.optional (!ok) name;

  nixosRules =
    host: c:
    let
      fw = c.networking.firewall;
      ssh = c.services.openssh;
      except = list: lib.elem host list;
      # SSH's own port is the SSH rule's business, below
      tcpPorts = if except sshToInternet then lib.remove 22 fw.allowedTCPPorts else fw.allowedTCPPorts;
    in
    lib.concatLists [
      (rule "networking.hostName is the configuration's name" (c.networking.hostName == host))
      (rule "the firewall is on" fw.enable)
      (rule "no interface is trusted but lo" (fw.trustedInterfaces == [ "lo" ]))
      (rule "no port is open outside tailscale0" (
        except lanPorts
        || lib.all (ports: ports == [ ]) [
          tcpPorts
          fw.allowedUDPPorts
          fw.allowedTCPPortRanges
          fw.allowedUDPPortRanges
        ]
      ))
      (rule "SSH is open on tailscale0 only" (
        !ssh.enable || (!ssh.openFirewall && (except sshToInternet || !lib.elem 22 fw.allowedTCPPorts))
      ))
      (rule "SSH takes keys only" (
        !ssh.enable || (!ssh.settings.PasswordAuthentication && !ssh.settings.KbdInteractiveAuthentication)
      ))
      (rule "SSH refuses root" (!ssh.enable || ssh.settings.PermitRootLogin == "no"))
      (rule "SSH is on, through custom.ssh-server" (except wsl || c.custom.ssh-server.enable))
      (rule "Tailscale is on" (except wsl || c.services.tailscale.enable))
      (rule "the heartbeat is on" (except wsl || c.custom.heartbeat.enable))
      (rule "the Beszel agent is on" (except wsl || c.custom.beszel-agent.enable))
    ];

  darwinRules =
    host: c:
    lib.concatLists [
      (rule "networking.hostName is the configuration's name" (c.networking.hostName == host))
      (rule "Tailscale is on" c.services.tailscale.enable)
      (rule "the heartbeat is on" c.custom.heartbeat.enable)
      (rule "the Beszel agent is on" c.custom.beszel-agent.enable)
    ];

  failures = lib.concatLists (
    lib.mapAttrsToList (
      host: h: map (r: "${host}: ${r}") (nixosRules host h.config)
    ) nixosConfigurations
    ++ lib.mapAttrsToList (
      host: h: map (r: "${host}: ${r}") (darwinRules host h.config)
    ) darwinConfigurations
  );
in
pkgs.runCommand "invariants"
  {
    report =
      if failures == [ ] then
        "every host keeps every rule"
      else
        lib.concatMapStrings (f: "broken: ${f}\n") failures;
    failed = failures != [ ];
  }
  ''
    printf '%s\n' "$report"
    if [ -n "$failed" ]; then exit 1; fi
    touch "$out"
  ''
