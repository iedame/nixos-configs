{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    # Private repo holding the agenix-encrypted secrets and their recipient
    # rules (plain files, not a flake). Fetched over SSH, so evaluating this
    # config needs access to it. After changing a secret there:
    # `nix flake update secrets`.
    secrets = {
      url = "git+ssh://git@github.com/iedame/nixos-secrets.git";
      flake = false;
    };

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    # Declarative disk partitioning, used to install Tsukuba
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Per-model hardware profiles (Tsukuba is a MacBookPro8,1)
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixos-hardware.inputs.nixpkgs.follows = "nixpkgs";

    # Homebrew itself, plus its core/cask taps pinned like any other input
    # (bumped by the weekly flake update)
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    nixkeeper.url = "github:iedame/nixkeeper";
    nixkeeper.inputs.nixpkgs.follows = "nixpkgs";
    nixkeeper.inputs.nix-darwin.follows = "nix-darwin";
    nixkeeper.inputs.treefmt-nix.follows = "treefmt-nix";

    # Formatter setup for `nix fmt` and the formatting check
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ self, ... }:
    let
      forAllSystems = inputs.nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      # `nix fmt` formats everything; checks.formatting fails on anything
      # unformatted.
      treefmt = forAllSystems (
        system:
        inputs.treefmt-nix.lib.evalModule inputs.nixpkgs.legacyPackages.${system} {
          projectRootFile = "flake.nix";
          programs = {
            nixfmt.enable = true;
            # Keeps the marked blocks sorted (the package lists; see the
            # README). Nix files only, because the README quotes the marker
            # comments in prose. Don't write the marker text in a comment
            # here either: the tool would take it for a real marker.
            keep-sorted = {
              enable = true;
              includes = [ "*.nix" ];
            };
          };
        }
      );

      oracleMicro =
        host:
        inputs.nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs;
          };
          modules = [
            self.nixosModules.default
            self.nixosModules.oracle-micro
            host
          ];
        };
    in
    {
      nixosModules = {
        default = {
          imports = [
            ./modules/nixos/nix-core.nix
            ./modules/nixos/locale.nix
            ./modules/nixos/fonts.nix
            ./modules/nixos/plasma.nix
            ./modules/nixos/ssh-server.nix
          ];
        };

        # Sets home-manager options, so only for hosts that use home-manager
        # as a NixOS module
        runescape = ./modules/nixos/runescape.nix;

        # Oracle Cloud micro instances; describes their hardware and disk
        oracle-micro = ./modules/nixos/oracle-micro.nix;
      };

      darwinModules.default = {
        imports = [
          ./modules/darwin/nix-core.nix
          ./modules/darwin/fonts.nix
        ];
      };

      homeModules = {
        default = {
          imports = [
            ./modules/home-manager/zsh.nix
            ./modules/home-manager/alacritty.nix
            ./modules/home-manager/nh.nix
            ./modules/home-manager/nix-index.nix
            ./modules/home-manager/git.nix
            ./modules/home-manager/ssh.nix
            ./modules/home-manager/shell-tools.nix
            ./modules/home-manager/claude-code.nix
            inputs.nix-index-database.homeModules.nix-index
          ];
        };

        # macOS-only modules (launchd services); imported by darwin hosts only
        darwin = {
          imports = [
            ./modules/home-manager/darwin/linkding.nix
          ];
        };
      };

      nixosConfigurations.Aurora = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
        };
        modules = [
          self.nixosModules.default
          self.nixosModules.runescape
          ./hosts/Aurora
          inputs.agenix.nixosModules.default
          inputs.home-manager.nixosModules.home-manager
          {
            home-manager.backupFileExtension = "backup";
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.haoji = import ./hosts/Aurora/users/haoji;
            home-manager.extraSpecialArgs = {
              inherit inputs;
            };
            home-manager.sharedModules = [
              self.homeModules.default
            ];
          }
        ];
      };

      # No agenix and no home-manager here: the laptop updates itself from
      # the public repo (system.autoUpgrade) and must evaluate without
      # access to the private `secrets` input.
      nixosConfigurations.Tsukuba = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
        };
        modules = [
          self.nixosModules.default
          ./hosts/Tsukuba
          inputs.disko.nixosModules.disko
          inputs.nixos-hardware.nixosModules.apple-macbook-pro-8-1
        ];
      };

      # Oracle Cloud Always Free micro instances
      nixosConfigurations.Narita = oracleMicro ./hosts/Narita;

      darwinConfigurations.Kawagoe = inputs.nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = {
          inherit inputs;
          flake = self;
        };
        modules = [
          {
            nixpkgs.overlays = [
              (final: prev: { linkding = final.callPackage ./overlays/Kawagoe/linkding.nix { }; })
            ];
          }
          self.darwinModules.default
          ./hosts/Kawagoe
          inputs.agenix.darwinModules.default
          inputs.nix-homebrew.darwinModules.nix-homebrew
          inputs.home-manager.darwinModules.home-manager
          {
            home-manager.backupFileExtension = "backup";
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.haoji = import ./hosts/Kawagoe/users/haoji;
            home-manager.extraSpecialArgs = {
              inherit inputs;
            };
            home-manager.sharedModules = [
              self.homeModules.default
              self.homeModules.darwin
            ];
          }
          inputs.nixkeeper.darwinModules.default
          {
            # Running the community instance via Cloudflare instead: https://nixkeeper.com
            services.nixkeeper = {
              enable = false;
              lists.maintainers = [ "iedame" ];
            };
          }
        ];
      };

      formatter = forAllSystems (system: treefmt.${system}.config.build.wrapper);

      checks = forAllSystems (system: {
        formatting = treefmt.${system}.config.build.check self;
      });
    };
}
