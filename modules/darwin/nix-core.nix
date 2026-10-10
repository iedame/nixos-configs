{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.custom.nix-core;
in
{
  options.custom.nix-core = {
    enable = lib.mkEnableOption "Shared Nix and Nixpkgs configuration for Darwin hosts";
    gc.deleteOlderThan = lib.mkOption {
      type = lib.types.str;
      default = "7d";
      description = "Age passed to nix-collect-garbage --delete-older-than.";
    };
    trustedUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra trusted Nix users (root is always trusted by the platform default)";
    };
    extraPlatforms = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra platforms, e.g. x86_64-darwin for building Intel binaries via Rosetta";
    };
    build = {
      maxJobs = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        description = "Packages built at the same time (nix max-jobs); null keeps Nix's default of one per CPU";
      };
      cores = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        description = "CPU cores each build may use (nix cores); null keeps Nix's default of all cores";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        nix = {
          nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
          registry = {
            nixpkgs.flake = inputs.nixpkgs;
          };
          settings = {
            experimental-features = [
              "nix-command"
              "flakes"
            ];
          };
        };
        nixpkgs.config.allowUnfree = true;
      }
      {
        # Scheduled GC + store optimisation via launchd. Darwin has no
        # dates/persistent/randomizedDelaySec; launchd coalesces a missed
        # calendar job and fires it once on next wake.
        nix.gc = {
          automatic = true;
          interval = lib.mkDefault [
            {
              Weekday = 7;
              Hour = 4;
              Minute = 0;
            }
          ];
          options = "--delete-older-than ${cfg.gc.deleteOlderThan}";
        };
        nix.optimise = {
          automatic = true;
          interval = lib.mkDefault [
            {
              Weekday = 7;
              Hour = 5;
              Minute = 0;
            }
          ];
        };
      }
      (lib.mkIf (cfg.trustedUsers != [ ]) {
        nix.settings.trusted-users = cfg.trustedUsers;
      })
      (lib.mkIf (cfg.extraPlatforms != [ ]) {
        nix.settings.extra-platforms = cfg.extraPlatforms;
      })
      (lib.mkIf (cfg.build.maxJobs != null) {
        nix.settings.max-jobs = cfg.build.maxJobs;
      })
      (lib.mkIf (cfg.build.cores != null) {
        nix.settings.cores = cfg.build.cores;
      })
    ]
  );
}
