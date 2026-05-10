# Example: how to wire prolix into your system flake.
#
# This shows the two additions needed in your existing flake.nix:
#   1. Add prolix as an input
#   2. Import prolix.flakeModules.default and your my-projects.nix in perSystem
#
# Everything else is your existing flake structure — nothing else changes.

{
  description = "My NixOS configuration";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 1. Add prolix as an input.
    prolix = {
      url = "github:owner/prolix";
      inputs.nixpkgs.follows     = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
      inputs.flake-parts.follows  = "flake-parts";
    };
  };

  outputs = inputs@{ flake-parts, prolix, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" ];

      # 2. Import the prolix flake-parts module at the top level.
      imports = [ prolix.flakeModules.default ];

      perSystem = { pkgs, ... }: {
        # 3. Import your projects file inside perSystem so pkgs is available.
        imports = [ ../my-projects.nix ];
        #          ^^ adjust path to wherever you keep my-projects.nix
      };

      flake = {
        # Your NixOS / home-manager configurations live here as usual.
        homeConfigurations."alice@hostname" = inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
          modules = [
            # 4. Import the prolix HM module + your projects file.
            prolix.homeManagerModules.default
            ../my-projects.nix
            #   ^^ same file, imported in both places

            # ... your other HM modules
            ./home.nix
          ];
          extraSpecialArgs = { inherit inputs; };
        };
      };
    };
}
