# The system every Mac gets: which domains, plus the state versions. Nothing here is
# about one machine; differences between Macs come from the context repos present on
# each (see contexts/). The chip is picked by `config rebuild` (see flake.nix).
{ ... }:
{
  imports = [
    ./nix
    ./shell
    ./cli
    ./projects
    ./editor
    ./workspace
    ./contexts
    ./git
    ./apps
    ./macos
    ./ai
  ];

  # Format versions of the state each tool created on first install. They don't
  # track releases; read the nix-darwin / home-manager changelogs before changing.
  system.stateVersion = 7;
  hm.home.stateVersion = "26.05";
}
