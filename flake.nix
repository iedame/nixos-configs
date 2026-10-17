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

    nixkeeper.url = "github:nixkeeper/nixkeeper";
    nixkeeper.inputs.nixpkgs.follows = "nixpkgs";
    nixkeeper.inputs.nix-darwin.follows = "nix-darwin";
    nixkeeper.inputs.treefmt-nix.follows = "treefmt-nix";

    # NixOS under WSL, for Akihabara
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

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

      # An Oracle Cloud host: `shape` is the module describing its machine
      # (nixosModules.oracle-micro or nixosModules.oracle-a1), which also
      # sets its platform
      oracle =
        shape: host:
        inputs.nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
          };
          modules = [
            self.nixosModules.default
            shape
            inputs.agenix.nixosModules.default
            host
          ];
        };
    in
    {
      nixosModules = {
        default = {
          imports = [
            ./modules/nixos/nix-core.nix
            ./modules/nixos/disk-health.nix
            ./modules/nixos/family-laptop.nix
            ./modules/nixos/flatpak.nix
            ./modules/nixos/locale.nix
            ./modules/nixos/notify.nix
            ./modules/nixos/fonts.nix
            ./modules/nixos/heartbeat.nix
            ./modules/nixos/linkding-backup.nix
            ./modules/nixos/plasma.nix
            ./modules/nixos/reboot-for-kernel.nix
            ./modules/nixos/reboot-notice.nix
            ./modules/nixos/self-deploy.nix
            ./modules/nixos/ssh-server.nix
            ./modules/nixos/tailscale-services.nix
            ./modules/nixos/uptime-kuma-backup.nix
          ];
        };

        # Sets home-manager options, so only for hosts that use home-manager
        # as a NixOS module
        runescape = ./modules/nixos/runescape.nix;

        # Oracle Cloud instances, by shape; each describes its hardware and
        # disk (and imports oracle.nix, what they share)
        oracle-micro = ./modules/nixos/oracle-micro.nix;
        oracle-a1 = ./modules/nixos/oracle-a1.nix;
      };

      darwinModules.default = {
        imports = [
          ./modules/darwin/nix-core.nix
          ./modules/darwin/fonts.nix
          ./modules/darwin/heartbeat.nix
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

      # The same kind of laptop as Tsukuba, a 2013 model
      nixosConfigurations.Kawaguchiko = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
        };
        modules = [
          self.nixosModules.default
          ./hosts/Kawaguchiko
          inputs.disko.nixosModules.disko
          inputs.nixos-hardware.nixosModules.apple-macbook-pro-11-1
        ];
      };

      # NixOS under WSL on the gaming laptop; home-manager like Aurora's,
      # but no agenix
      nixosConfigurations.Akihabara = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
        };
        modules = [
          self.nixosModules.default
          ./hosts/Akihabara
          inputs.nixos-wsl.nixosModules.default
          inputs.home-manager.nixosModules.home-manager
          {
            home-manager.backupFileExtension = "backup";
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.haoji = import ./hosts/Akihabara/users/haoji;
            home-manager.extraSpecialArgs = {
              inherit inputs;
            };
            home-manager.sharedModules = [
              self.homeModules.default
            ];
          }
        ];
      };

      # Oracle Cloud Always Free micro instances
      nixosConfigurations.Narita = oracle self.nixosModules.oracle-micro ./hosts/Narita;
      nixosConfigurations.Nikko = oracle self.nixosModules.oracle-micro ./hosts/Nikko;
      # Oracle Cloud Always Free Ampere A1 instance
      nixosConfigurations.Ginza = oracle self.nixosModules.oracle-a1 ./hosts/Ginza;

      darwinConfigurations.Kawagoe = inputs.nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = {
          inherit inputs;
          flake = self;
        };
        modules = [
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
