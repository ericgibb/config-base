# Nix itself and operating this repo: daemon settings, cleanup, and the `config`
# command (status, rebuild, check, update, rollback; see config.sh).
{
  config,
  inputs,
  user,
  ...
}:
{
  nix = {
    # nix-darwin takes over /etc/nix/nix.conf from here on.
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        user.name
      ];
      # Avoid "warning: Git tree is dirty" noise while editing this repo.
      warn-dirty = false;
    };

    # Hard-link identical store files on a schedule (safer than auto-optimise-store on macOS).
    optimise.automatic = true;

    # Weekly cleanup of store paths older than 30 days. Old generations stay rollback-able until then.
    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 3;
        Minute = 0;
      };
      options = "--delete-older-than 30d";
    };
  };

  # Claude Code and some apps are unfree.
  nixpkgs.config.allowUnfree = true;

  # `darwin-version` shows which git commit of this repo is active.
  system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

  hm =
    { lib, pkgs, ... }:
    {
      home.packages = with pkgs; [
        # `config`: the entry point for this setup. No runtimeInputs on purpose: its
        # status view must see your PATH exactly as it is.
        (writeShellApplication {
          name = "config";
          text = ''
            CONFIG_FLAKE="$HOME/config"
            JQ=${lib.getExe jq}
            GIT=${lib.getExe git}
            NVD=${lib.getExe nvd}
            STAT=${coreutils}/bin/stat
            DATE=${coreutils}/bin/date
            REALPATH=${coreutils}/bin/realpath
            CONTEXT_SEARCH=${lib.escapeShellArg (lib.concatStringsSep ":" config.contexts.search)}
            CONTEXT_TEMPLATE=${config.contexts.template}
          ''
          + builtins.readFile ./config.sh;
        })
        nixfmt # formatter (also `nix fmt` in this repo)
        nil # Nix language server, for editor support
        nix-tree # explore what's in your closure
        nvd # human-readable diff between system generations
      ];

      # Only zsh knows its aliases, functions and builtins, so `config which` asks it
      # first, then lets the `config` command trace PATH.
      programs.zsh.initContent = ''
        config() {
          if [[ "$1" == which && -n "$2" ]]; then
            local kind="$(whence -w -- "$2" 2>/dev/null)"
            case "''${kind##*: }" in
              alias|function|builtin|reserved)
                whence -v -- "$2"
                command config "$@" 2>/dev/null
                return 0 ;;
            esac
          fi
          command config "$@"
        }
      '';
    };
}
