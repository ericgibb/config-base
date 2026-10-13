# Project environments: how a folder gets its own toolchain.
#
# Each project carries a flake.nix (its tools, pinned by its own flake.lock) and an
# .envrc. direnv loads them when you `cd` in and unloads them when you leave.
# How much of your global setup a project sees is chosen per project in its .envrc:
#
#   inherit    `use flake`             devShell layered on top of your full shell
#   isolated   `isolate` + `use flake` only the flake + a few kept host tools + macOS base
#   bare       `isolate --bare` + …    only the flake + nix (+ tools you list) + macOS base
#   pure       `nix develop -i …`      nothing at all from your shell (one-off checks, CI-like)
#
# `isolate` is defined in ./isolate.sh. New projects: ask an agent to use the
# `new-project` skill. Inspect what a folder is getting with `config`.
{ ... }:
{
  hm = {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true; # cached `use flake`, survives garbage collection
      config.global = {
        hide_env_diff = true;
        warn_timeout = "30s"; # first load of a new flake can take a while
      };
    };

    # direnv sources every file in ~/.config/direnv/lib/ before running an .envrc.
    xdg.configFile."direnv/lib/isolate.sh".source = ./isolate.sh;
  };
}
