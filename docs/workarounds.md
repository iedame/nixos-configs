# Workarounds and pins

Every temporary fix in this repository, and every version pinned for a
reason, with what makes it removable. Check the list after each lock
update: a fix that outlives its reason is easy to forget.

- **Adding**: a change that adds a temporary fix or a pin adds its row
  here in the same pull request, and marks the code with a `TEMPORARY`
  comment that names the row's ID.
- **Removing**: once the condition is met, remove the code and the row
  together, with the ID in the commit message. IDs are not reused.

## Temporary fixes

| ID | What and where | Why | Remove when |
|---|---|---|---|
| WA-6 | Kawagoe builds Beszel with two more tests skipped, `TestLegacyHubGetsSinglePayload` and `TestMonitorICMPLoopback` (`modules/darwin/beszel-agent.nix`); since 2026-11-06 | The first times out on macOS since Beszel 0.21.1, so the package doesn't build there, and nixpkgs' build farm fails it too (NixOS/nixpkgs#583287). Kawagoe builds Beszel itself meanwhile, as the cache has no macOS build, and there the second fails as well: it pings 127.0.0.1, which Kawagoe's firewall (stealth mode) doesn't answer | NixOS/nixpkgs#583287 is fixed, or `beszel` builds on aarch64-darwin on Hydra again |
| WA-7 | Kawagoe builds zapfast with the system's OpenSSL and SQLCipher, and without perl (`hosts/Kawagoe/default.nix`, an overlay); since 2026-11-11 | zapfast 0.21.1 fails to build on macOS: openssl-sys can't find OpenSSL. The fix, NixOS/nixpkgs#585883, makes this same change but isn't in nixos-unstable yet | The lock's nixpkgs includes NixOS/nixpkgs#585883 |

Removed: WA-1, the broadcom-sta install fix, and WA-2, mcp-nixos on mcp
1.x, both with the lock update of 2026-10-29.

## Pins

| ID | What and where | Why | Revisit when |
|---|---|---|---|
| WA-3 | CI runs on `ubuntu-24.04` and `ubuntu-24.04-arm`, not `ubuntu-latest` (`.github/workflows/`); since 2026-10-27 (#103) | The step that lets Nix's build sandbox create namespaces is specific to Ubuntu 24.04's AppArmor | Moving to a newer Ubuntu image: check that the sandbox step still applies, or what replaces it. |
| WA-4 | Kawagoe's CI job runs on `macos-26` (`.github/workflows/ci.yml`); since 2026-10-27 (#103) | It builds Kawagoe's system on Kawagoe's macOS version | Kawagoe moves to a new macOS: bump it to match. |
| WA-5 | Forgejo is `pkgs.forgejo`, the current release, not the module's long-term one (`hosts/Ginza/default.nix`); since 2026-10-19 (#81) | The long-term release is older and refuses the database, which a newer Forgejo has already migrated | Only if we want the long-term releases again: possible once one is at least as new as the database. |
