# Plumbing, not a domain: wires your user account into the system and provides
# the `hm` shorthand every domain uses for per-user (home directory) settings.
#
#   programs.zsh.enable = true;      # system level (nix-darwin)
#   hm.programs.zsh.enable = true;   # your user (home-manager), same as
#                                    # home-manager.users.<you>.programs.zsh.enable
{
  inputs,
  lib,
  user,
  ...
}:
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
    (lib.mkAliasOptionModule [ "hm" ] [ "home-manager" "users" user.name ])
  ];

  # The account that owns per-user settings nix-darwin applies (defaults, Homebrew).
  system.primaryUser = user.name;
  users.users.${user.name}.home = "/Users/${user.name}";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # Existing dotfiles (e.g. ~/.zshrc) are renamed instead of failing the switch.
    backupFileExtension = "before-nix";
    extraSpecialArgs = { inherit user; };
  };

  hm = {
    home.username = user.name;
    home.homeDirectory = "/Users/${user.name}";
    # Lets home-manager manage itself (`home-manager` command, news).
    programs.home-manager.enable = true;
  };
}
