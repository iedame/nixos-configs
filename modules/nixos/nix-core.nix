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
    enable = lib.mkEnableOption "Shared Nix and Nixpkgs configuration for NixOS hosts";
    gc.deleteOlderThan = lib.mkOption {
      type = lib.types.str;
      default = "7d";
      description = "Generations newer than this are kept (nh clean --keep-since).";
    };
    gc.keep = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3;
      description = "Always keep at least this many generations per profile (nh clean --keep).";
    };
    trustedUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra trusted Nix users (root is always trusted by the platform default)";
    };
    extraPlatforms = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra platforms for cross-compilation support";
    };
    ciCache.enable = lib.mkEnableOption ''
      downloading the packages this repository's CI builds and uploads (the
      ones cache.nixos.org doesn't have; see .github/workflows/ci.yml)
    '';
    ciCache.bucket = lib.mkOption {
      type = lib.types.str;
      default = "nixos-configs-cache";
      description = "The cache's Cloudflare R2 bucket.";
    };
    ciCache.endpoint = lib.mkOption {
      type = lib.types.str;
      default = "ebce6e5a60de848f692507c157f09f80.r2.cloudflarestorage.com";
      description = "Host name of the S3 API of the R2 account the bucket is in.";
    };
    permittedInsecurePackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of insecure packages to permit";
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
        # Scheduled garbage collection via `nh clean all` rather than nix.gc:
        # nix-collect-garbage --delete-older-than keeps only the current
        # generation once everything is old, while --keep always leaves a
        # rollback target. Store optimisation stays on its own timer.
        programs.nh = {
          enable = true;
          clean = {
            enable = true;
            dates = lib.mkDefault "Sun 04:00";
            extraArgs = "--keep ${toString cfg.gc.keep} --keep-since ${cfg.gc.deleteOlderThan}";
          };
        };
        nix.optimise = {
          automatic = true;
          dates = lib.mkDefault [ "Sun 05:00" ];
          randomizedDelaySec = "30min";
        };
      }
      (lib.mkIf (cfg.trustedUsers != [ ]) {
        nix.settings.trusted-users = cfg.trustedUsers;
      })
      (lib.mkIf (cfg.extraPlatforms != [ ]) {
        nix.settings.extra-platforms = cfg.extraPlatforms;
      })
      (lib.mkIf cfg.ciCache.enable {
        # A private Cloudflare R2 bucket, read through its S3 API with a
        # read-only token that is placed on the machine by hand, in root's
        # AWS credentials file, /root/.aws/credentials (see README.md,
        # "Binary cache"). Nix finds it there whether root runs it or the
        # daemon does. Without that file Nix warns and carries on with
        # cache.nixos.org alone.
        nix.settings = {
          extra-substituters = [
            "s3://${cfg.ciCache.bucket}?endpoint=${cfg.ciCache.endpoint}&region=auto"
          ];
          extra-trusted-public-keys = [
            "nixos-configs-cache-1:CW5tDg3uwOBmz8C2a29loFeNcqo4sjInPjTgd0zIhOc="
          ];
        };
      })
      (lib.mkIf (cfg.permittedInsecurePackages != [ ]) {
        nixpkgs.config.permittedInsecurePackages = cfg.permittedInsecurePackages;
      })
    ]
  );
}
