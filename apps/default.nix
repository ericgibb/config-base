# Applications: WHAT you want installed. HOW they get installed is the backend
# imported below (Homebrew on macOS). Add an app here, then `config rebuild`.
{ lib, ... }:
{
  imports = [
    # The macOS backend. On another OS, import that OS's backend file instead;
    # this file and the list below stay the same.
    ./homebrew.nix
  ];

  options.apps = {
    desktop = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Desktop applications to install. Names are Homebrew cask names
        (https://formulae.brew.sh, `brew search --cask <name>`); a future backend
        can map them to its own package names.
      '';
    };

    cli = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Command-line programs that should come from the apps backend rather than
        nixpkgs (vendor-signed builds, or ones nixpkgs can't provide prebuilt).
        Prefer nixpkgs (cli/) for everything else. Other domains add to this list.
      '';
    };

    appStore = lib.mkOption {
      type = lib.types.attrsOf lib.types.int;
      default = { };
      description = ''
        Mac App Store apps as `name = app id;` (requires being signed in to the App
        Store). Find ids with `nix run nixpkgs#mas -- search <name>`.
      '';
    };
  };

  config.apps = {
    desktop = [
      "spotify"
      "1password"
    ];
    # Other domains add their own apps: e.g. editor/ adds Zed.

    # `op` must be the vendor build for the 1Password app integration to work.
    cli = [ "1password-cli" ];

    appStore = { };
  };
}
