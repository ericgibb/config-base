{
  description = "@NAME@ context for ~/config (applies to ~/@DIRECTORY@)";

  # Used by the shell layer below. During `config rebuild` it follows ~/config's nixpkgs.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "aarch64-darwin" ]; # same as ~/config
    in
    {
      context.name = "@NAME@";

      # Added to the system by `config rebuild`. Same options as ~/config.
      darwinModules.default = ./module.nix;

      # The shell layer for everything under ~/@DIRECTORY@ (loaded by direnv).
      # Projects below inherit it by keeping `source_up_if_exists` in their .envrc.
      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShellNoCC {
          packages = with nixpkgs.legacyPackages.${system}; [
            # tools every project in this context uses
          ];
        };
      });
    };
}
