# Command-line tools from nixpkgs. Search: https://search.nixos.org/packages
# or `nix search nixpkgs <name>`. Try one without installing: `nix shell nixpkgs#<name>`.
# Tools that shape the shell itself (fzf, zoxide, eza, bat) live in shell/.
{ pkgs, ... }:
{
  hm.home.packages = with pkgs; [
    # Core utilities
    coreutils
    curl
    wget
    jq
    yq-go
    ripgrep
    fd
    tree
    btop
    watch

    # Dev
    just
    shellcheck
  ];
}
