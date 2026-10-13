# macOS backend for apps/: installs `apps.desktop` and `apps.cli` as Homebrew casks and
# `apps.appStore` via mas. nix-homebrew installs and pins Homebrew itself.
# Nothing outside this file knows Homebrew is involved.
{
  config,
  inputs,
  user,
  ...
}:
{
  imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

  nix-homebrew = {
    enable = true;
    user = user.name;
    autoMigrate = true; # adopt an existing /opt/homebrew if one is there
  };

  homebrew = {
    enable = true;
    # Puts /opt/homebrew/bin on PATH (for `op`, `zed`, `claude`) in every zsh session.
    enableZshIntegration = true;

    casks = config.apps.desktop ++ config.apps.cli;
    masApps = config.apps.appStore;

    onActivation = {
      # Start permissive. Once every app you use is listed in apps/default.nix,
      # switch to "zap" so anything installed by hand is removed on each rebuild.
      cleanup = "none";
      autoUpdate = false; # don't refresh Homebrew's index on every rebuild
      upgrade = false; # don't upgrade casks on every rebuild (most apps self-update)
    };
  };
}
