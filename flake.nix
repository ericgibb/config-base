{
  description = "A forkable macOS setup, organized by domain (shell, apps, ai, …)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # macOS system layer. Used by lib/ and the darwin-specific parts of each domain.
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Per-user layer (everything under ~). Domains reach it through `hm.*`.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Installs and pins Homebrew itself. Used only by apps/homebrew.nix.
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs =
    inputs@{ nixpkgs, nix-darwin, ... }:
    let
      # You, on every Mac. Forking this repo? These lines are the only place you're named.
      user = {
        name = "eric"; # macOS short username (`whoami`)
        fullName = "Eric Gibb";
        email = "ericgibb@gmail.com";
        github = "ericgibb"; # where your signing keys are published (see workspace/)
      };

      # Every Mac gets the same system: lib/ plumbing + system.nix (the domains), plus the
      # context repos `config rebuild` finds on that Mac (see contexts/). Nothing in
      # this repo names a machine.
      mkSystem =
        {
          system,
          contexts ? [ ],
        }:
        nix-darwin.lib.darwinSystem {
          specialArgs = { inherit inputs user; };
          modules = [
            ./lib/user.nix
            ./system.nix
            {
              nixpkgs.hostPlatform = system;
              contexts.loaded = map (c: removeAttrs c [ "module" ]) contexts;
            }
          ]
          ++ map (c: c.module) contexts;
        };

      # Apple silicon. (nixpkgs-unstable dropped Intel Macs in 26.11.)
      forAllSystems = nixpkgs.lib.genAttrs [ "aarch64-darwin" ];
    in
    {
      # The system, without contexts. `config rebuild` builds it through a generated
      # wrapper that adds the contexts it found on this Mac.
      darwinConfigurations = forAllSystems (system: mkSystem { inherit system; });
      lib = { inherit mkSystem; };

      # `nix fmt` formats every .nix file in the repo.
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
