# shellcheck shell=bash
# `isolate`: a project's shell sees its own flake, not your global setup.
# direnv loads this file from ~/.config/direnv/lib/ (managed in ~/config/projects/).
#
# In a project's .envrc, call it BEFORE `use flake`:
#
#   isolate              # drop global tools and toolchain variables; keep shell + agent basics
#   isolate jq rg        # ...and also keep these host tools
#   isolate --bare       # keep only `nix` (plus any tools you list)
#   use flake
#
# Resulting PATH: flake devShell → .direnv/host-bin (kept tools) → macOS base.
# Without `isolate`, a project "inherits": the devShell is layered on top of your full shell.

# Interactive basics your aliases and agents rely on (ls=eza, cat=bat, z, Ctrl-R, git,
# AI CLIs, `config`, `direnv allow`). Everything else must come from the project's flake.
ISOLATE_DEFAULT_KEEP=(git gh direnv config zed claude codex op eza bat fzf zoxide)

# Where kept tools are looked up: the layers ~/config installs into, in priority order.
ISOLATE_HOST_DIRS=(
  "/etc/profiles/per-user/${USER:-$(id -un)}/bin" # home-manager
  "/run/current-system/sw/bin"                     # nix-darwin
  "/opt/homebrew/bin"                              # Homebrew (apps/)
  "/nix/var/nix/profiles/default/bin"              # Nix installer profile
  "$HOME/.local/bin"
  "/usr/local/bin"
)

# Toolchain variables that change how builds behave. Unset so only the flake sets them.
ISOLATE_UNSET_VARS=(
  NODE_OPTIONS NODE_PATH NPM_CONFIG_PREFIX npm_config_prefix
  PYTHONPATH PYTHONHOME PYTHONSTARTUP VIRTUAL_ENV CONDA_PREFIX PIP_REQUIRE_VIRTUALENV
  GOPATH GOBIN GOROOT GOFLAGS GOTOOLCHAIN
  CARGO_HOME RUSTUP_HOME RUSTFLAGS RUSTC_WRAPPER
  GEM_HOME GEM_PATH BUNDLE_PATH JAVA_HOME
  DYLD_LIBRARY_PATH DYLD_FALLBACK_LIBRARY_PATH LD_LIBRARY_PATH
  PKG_CONFIG_PATH CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH
  CFLAGS CXXFLAGS CPPFLAGS LDFLAGS INFOPATH
)

isolate() {
  local bare="" extra=() keep=() t d v

  while (($#)); do
    case "$1" in
    --bare) bare=1 ;;
    -*)
      log_error "isolate: unknown option $1"
      return 1
      ;;
    *) extra+=("$1") ;;
    esac
    shift
  done

  # nix-direnv needs `nix` itself to load the flake.
  keep=(nix)
  [[ -n "$bare" ]] || keep+=("${ISOLATE_DEFAULT_KEEP[@]}")
  keep+=("${extra[@]}")

  # 1. Kept host tools become symlinks in one project-local folder.
  local hostbin missing=()
  hostbin="$(direnv_layout_dir)/host-bin"
  rm -rf "$hostbin"
  mkdir -p "$hostbin"
  for t in "${keep[@]}"; do
    [[ -e "$hostbin/$t" ]] && continue
    local found=""
    for d in "${ISOLATE_HOST_DIRS[@]}"; do
      if [[ -x "$d/$t" && ! -d "$d/$t" ]]; then
        ln -s "$d/$t" "$hostbin/$t"
        found=1
        break
      fi
    done
    [[ -n "$found" ]] || missing+=("$t")
  done
  if ((${#missing[@]})); then
    log_status "isolate: not installed on this machine, skipped: ${missing[*]}"
  fi

  # 2. Forget toolchain variables (and Homebrew's) inherited from your shell.
  for v in "${ISOLATE_UNSET_VARS[@]}"; do
    unset "$v"
  done
  while read -r v; do
    [[ "$v" == HOMEBREW_* ]] && unset "$v"
  done < <(compgen -e)

  # 3. PATH = kept tools + macOS base. `use flake` then puts the devShell in front.
  export PATH="$hostbin:/usr/bin:/bin:/usr/sbin:/sbin"
  if [[ -n "$bare" ]]; then
    export ISOLATE_MODE=bare
  else
    export ISOLATE_MODE=isolated
  fi
}
