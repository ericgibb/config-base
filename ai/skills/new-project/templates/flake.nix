{
  description = "<project name>: <one-line description>";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs: {
        # mkShellNoCC: no C compiler. Switch to pkgs.mkShell if anything compiles native code.
        default = pkgs.mkShellNoCC {
          # Every tool this project uses. In isolated/bare mode nothing else is on PATH.
          packages = with pkgs; [
            # <runtime / compiler>
            # <package manager>
            # <language server>
            # <formatter / linter>
            # <CLIs the project's scripts call, e.g. jq ripgrep>
          ];

          # Runs on every load. Keep it quiet and fast.
          shellHook = "";
        };
      });

      # `nix fmt` formats the Nix files.
      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
