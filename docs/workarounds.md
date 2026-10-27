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
| WA-1 | broadcom-sta installed with `make modules_install` (`modules/nixos/family-laptop.nix`); since 2026-10-20 | nixpkgs [#575192](https://github.com/NixOS/nixpkgs/issues/575192): the kernel's module collection expects `wl.ko.cer`, which the package doesn't install, so Tsukuba and Kawaguchiko fail to build | The locked nixpkgs contains the fix, 862bc5c ([#576651](https://github.com/NixOS/nixpkgs/pull/576651), merged 2026-10-25). Check below. |
| WA-2 | mcp-nixos built against mcp 1.x (`modules/home-manager/claude-code.nix`); since 2026-10-27 (#101) | nixpkgs moved `python3Packages.mcp` to 2.x, which marks fastmcp-slim broken, and mcp-nixos depends on it | `pkgs.mcp-nixos` evaluates without the override. Check below. |

Checks, from the repository on Kawagoe:

```bash
# WA-1: "ahead" or "identical" means the locked nixpkgs has the fix ("behind": not yet)
gh api repos/NixOS/nixpkgs/compare/862bc5c...$(nix flake metadata --json | jq -r .locks.nodes.nixpkgs.locked.rev) -q .status

# WA-2: prints a store path once mcp-nixos evaluates again (an error: not yet)
nix eval --raw .#darwinConfigurations.Kawagoe.pkgs.mcp-nixos.drvPath
```

## Pins

| ID | What and where | Why | Revisit when |
|---|---|---|---|
| WA-3 | CI runs on `ubuntu-24.04` and `ubuntu-24.04-arm`, not `ubuntu-latest` (`.github/workflows/`); since 2026-10-27 (#103) | The step that lets Nix's build sandbox create namespaces is specific to Ubuntu 24.04's AppArmor | Moving to a newer Ubuntu image: check that the sandbox step still applies, or what replaces it. |
| WA-4 | Kawagoe's CI job runs on `macos-26` (`.github/workflows/ci.yml`); since 2026-10-27 (#103) | It builds Kawagoe's system on Kawagoe's macOS version | Kawagoe moves to a new macOS: bump it to match. |
| WA-5 | Forgejo is `pkgs.forgejo`, the current release, not the module's long-term one (`hosts/Ginza/default.nix`); since 2026-10-19 (#81) | The long-term release is older and refuses the database, which a newer Forgejo has already migrated | Only if we want the long-term releases again: possible once one is at least as new as the database. |
