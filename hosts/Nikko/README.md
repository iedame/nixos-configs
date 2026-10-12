# Nikko

NixOS on an Oracle Cloud "Always Free" micro instance (the one that was
called `muspelheim` under Ubuntu), the twin of
[Narita](../Narita/README.md). It runs Uptime Kuma, reachable over Tailscale
at `https://kuma-nikko.<tailnet>.ts.net`, and is a Tailscale exit node.

That README covers how these hosts are installed and updated; the commands
are the same with `Nikko` and `nikko` in place of `Narita` and `narita`.

Like Narita it reports its health to the other server's Uptime Kuma; its
push URL is the agenix secret `nikko/heartbeat-url.age` (see Narita's README,
"Health reports"). Its Uptime Kuma is backed up the same way too, to the
folder `nikko` of the bucket (Narita's README, "Backup"; the command there
is `restic-uptime-kuma` on this host as well).
