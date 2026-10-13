# `config`: the one entry point for this machine's setup (~/config).
# Packaged by nix/default.nix. Status output shows provenance, never env var values.
#
#   config                 status: system, home, nix, shell files, session layers, PATH, folder
#   config which <cmd>     where a command comes from (every match on PATH, first one wins)
#   config rebuild         apply ~/config (build as you, activate as root)
#   config check           build without applying; show what would change
#   config update          update pinned inputs (nixpkgs, home-manager, ...)
#   config rollback        return to the previous system generation
#   config generations     list system generations
#   config edit            open ~/config in the editor
#   config contexts        context repos (~/Work/config, …): list, add, remove
#   config context new     scaffold a context repo
#   config signing         this Mac's git signing keys; upload them to GitHub
#
# Variables injected by the nix wrapper (defaults let the script run standalone):
CONFIG_FLAKE="${CONFIG_FLAKE:-$HOME/config}"
JQ="${JQ:-jq}"
GIT="${GIT:-git}"
STAT="${STAT:-stat}"
DATE="${DATE:-date}"
REALPATH="${REALPATH:-realpath}"
NVD="${NVD:-nvd}"
CONTEXT_SEARCH="${CONTEXT_SEARCH:-Personal/config:Work/config}"
CONTEXT_TEMPLATE="${CONTEXT_TEMPLATE:-$CONFIG_FLAKE/contexts/template}"
CONTEXTS_FILE="${CONTEXTS_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/config/contexts}"
STATE_DIR="${STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/config}"
SYSTEM_PROFILE="${SYSTEM_PROFILE:-/nix/var/nix/profiles/system}"
CURRENT_SYSTEM="${CURRENT_SYSTEM:-/run/current-system}"

# Every Mac builds the same system; only the chip picks which one (see flake.nix).
if [[ -z "${CONFIG_SYSTEM:-}" ]]; then
  case "$(uname -m)" in
  arm64 | aarch64) CONFIG_SYSTEM=aarch64-darwin ;;
  *) CONFIG_SYSTEM=x86_64-darwin ;;
  esac
fi

# ── output helpers ────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  B=$'\e[1m' D=$'\e[2m' G=$'\e[32m' Y=$'\e[33m' R=$'\e[0m'
else
  B="" D="" G="" Y="" R=""
fi
section() { printf '\n%s%s%s\n' "$B" "$1" "$R"; }
row() { printf '  %-30s %s\n' "$1" "$2"; }
ok() { printf '%s✓%s %s' "$G" "$R" "$1"; }
warn() { printf '%s!%s %s' "$Y" "$R" "$1"; }
dim() { printf '%s%s%s' "$D" "$1" "$R"; }
tilde() { local p="$1"; printf '%s' "${p/#$HOME/\~}"; }
# Shorten store paths for display: /nix/store/<hash>-pkg/bin → /nix/store/…-pkg/bin
short() {
  local p="$1"
  if [[ "$p" =~ ^/nix/store/[a-z0-9]{32}-(.*)$ ]]; then p="/nix/store/…-${BASH_REMATCH[1]}"; fi
  tilde "$p"
}

# "abc123…-ripgrep-15.2.0" → "ripgrep-15.2.0"
store_name() {
  local p="${1#/nix/store/}"
  p="${p%%/*}"
  printf '%s' "${p#*-}"
}

when() { # epoch seconds → "2026-10-02 18:01 (3 days ago)"
  local ts="$1" now days
  now="$("$DATE" +%s)"
  days=$(((now - ts) / 86400))
  local ago="today"
  if ((days == 1)); then ago="yesterday"; elif ((days > 1)); then ago="$days days ago"; fi
  printf '%s (%s)' "$("$DATE" -d "@$ts" '+%Y-%m-%d %H:%M')" "$ago"
}

generation_of() { # profile symlink → "generation N, built <when>"
  local profile="$1" link n ts
  link="$(readlink "$profile" 2>/dev/null)" || return 1
  n="${link%-link}"
  n="${n##*-}"
  ts="$("$STAT" -c %Y "$(dirname "$profile")/$link" 2>/dev/null || "$STAT" -c %Y "$profile")"
  printf 'generation %s, built %s' "$n" "$(when "$ts")"
}

# Who owns a dotfile/config file: nix-darwin, home-manager, or nobody.
owner_of() {
  local f="$1" target
  [[ -e "$f" || -L "$f" ]] || return 1
  if [[ -L "$f" ]]; then
    target="$(readlink "$f")"
    case "$target" in
    /etc/static/*) echo "nix-darwin" ;;
    *home-manager-files*) echo "home-manager" ;;
    /nix/store/*) echo "nix store ($(store_name "$target"))" ;;
    *) echo "symlink → $(tilde "$target") $(warn 'unmanaged')" ;;
    esac
  else
    case "$f" in
    "$HOME/.zshrc.local") echo "you (local, untracked by design)" ;;
    *) warn "unmanaged (not from ~/config)" ;;
    esac
  fi
}

# Which layer a PATH directory belongs to.
path_layer() {
  local d="$1" proj="${DIRENV_DIR:-}"
  proj="${proj#-}"
  if [[ -n "$proj" && "$d" == "$proj"/* ]]; then
    case "$d" in
    */.direnv/host-bin) echo "project: kept host tools (isolate)" ;;
    *) echo "project (.envrc)" ;;
    esac
    return
  fi
  case "$d" in
  "$HOME/.local/bin") echo "you (unmanaged scripts)" ;;
  "$HOME/.nix-profile/"* | "$HOME/.local/state/nix/profile"*) warn "imperative nix profile (not in ~/config)" ;;
  /etc/profiles/per-user/*) echo "home-manager (~/config, hm.*)" ;;
  /run/current-system/sw/*) echo "nix-darwin (~/config, system)" ;;
  /nix/var/nix/profiles/default/*) echo "Nix installer default profile" ;;
  /nix/store/*) echo "this session: $(store_name "$d")" ;;
  /opt/homebrew/*) echo "Homebrew (~/config apps/)" ;;
  /usr/local/*) echo "/usr/local (Intel Homebrew or manual installs)" ;;
  /usr/bin | /bin | /usr/sbin | /sbin | /System/* | /Library/Apple/* | /var/run/com.apple.* | /Applications/*) echo "macOS" ;;
  *) warn "other" ;;
  esac
}

# ── sections ──────────────────────────────────────────────────────────────────
show_system() {
  section "System"
  local json="$CURRENT_SYSTEM/darwin-version.json"
  if [[ ! -e "$json" ]]; then
    row "nix-darwin" "$(warn "not active (no $json)")"
    return
  fi
  local gen label active
  gen="$(generation_of "$SYSTEM_PROFILE" || echo "generation ?")"
  label="$("$JQ" -r '.darwinLabel // "?"' "$json")"
  active="$("$JQ" -r '.configurationRevision // ""' "$json")"
  row "nix-darwin" "$gen"
  row "this Mac" "$(scutil --get ComputerName 2>/dev/null || hostname -s) ($CONFIG_SYSTEM)"
  row "nixpkgs" "$label"

  if [[ ! -d "$CONFIG_FLAKE/.git" ]]; then
    row "built from" "$(warn "$(tilde "$CONFIG_FLAKE") is not a git repo")"
    return
  fi
  local head dirty="" state
  head="$("$GIT" -C "$CONFIG_FLAKE" rev-parse HEAD 2>/dev/null || echo "")"
  [[ -n "$("$GIT" -C "$CONFIG_FLAKE" status --porcelain 2>/dev/null)" ]] && dirty=1

  if [[ -z "$active" ]]; then
    state="$(warn "unknown revision (built before configurationRevision was set)")"
  elif [[ "$active" == *-dirty ]]; then
    state="$(warn "uncommitted changes from ${active:0:7} (not recorded in git)")"
  elif [[ "$active" == "$head" ]]; then
    state="$(ok "matches HEAD")"
  elif "$GIT" -C "$CONFIG_FLAKE" merge-base --is-ancestor "$active" "$head" 2>/dev/null; then
    local n
    n="$("$GIT" -C "$CONFIG_FLAKE" rev-list --count "$active..$head")"
    state="$(warn "$n newer commit(s) in the repo not applied; run \`config rebuild\`")"
  else
    state="$(warn "HEAD is ${head:0:7}, not a descendant of the active build")"
  fi
  row "built from" "$(tilde "$CONFIG_FLAKE") @ ${active:0:7}  $state"
  [[ -n "$dirty" ]] && row "" "$(warn "repo has uncommitted edits (not applied until \`config rebuild\`)")"

  local locked
  locked="$("$JQ" -r '.nodes.nixpkgs.locked.lastModified // empty' "$CONFIG_FLAKE/flake.lock" 2>/dev/null || true)"
  [[ -n "$locked" ]] && row "inputs locked" "nixpkgs $(when "$locked")  $(dim "(\`config update\` to bump)")"
}

show_home() {
  section "Home (home-manager)"
  local p
  for p in "${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/home-manager" \
    "/nix/var/nix/profiles/per-user/${USER:-$(id -un)}/home-manager"; do
    if [[ -L "$p" ]]; then
      row "profile" "$(generation_of "$p")"
      row "applied by" "nix-darwin on \`config rebuild\` (same build as System)"
      return
    fi
  done
  row "profile" "$(warn "no home-manager generation found")"
}

show_nix() {
  section "Nix"
  local ver=""
  if command -v nix >/dev/null 2>&1; then
    ver="$(nix --version 2>/dev/null | head -1 || true)"
    row "version" "${ver:-$(warn "\`nix --version\` failed")}  $(dim "($(short "$(command -v nix)"))")"
  else
    row "version" "$(warn "nix is not on PATH in this shell")"
  fi
  if [[ -S /nix/var/nix/daemon-socket/socket ]]; then
    row "daemon" "$(ok "running (multi-user)")"
  else
    row "daemon" "$(warn "socket not found")"
  fi

  # Settings are read in this order; later layers override earlier ones.
  local sys="/etc/nix/nix.conf" user="${XDG_CONFIG_HOME:-$HOME/.config}/nix/nix.conf"
  if [[ -e "$sys" ]]; then
    row "settings: $sys" "$(owner_of "$sys")"
  else
    row "settings: $sys" "$(warn "missing")"
  fi
  [[ -e /etc/nix/nix.custom.conf ]] && row "  + /etc/nix/nix.custom.conf" "$(owner_of /etc/nix/nix.custom.conf)"
  [[ -e "$user" ]] && row "  + $(tilde "$user")" "$(owner_of "$user")"
  [[ -n "${NIX_USER_CONF_FILES:-}" ]] && row "  + NIX_USER_CONF_FILES" "$(warn "set in environment (value hidden)")"
  [[ -n "${NIX_CONFIG:-}" ]] && row "  + NIX_CONFIG" "$(warn "set in environment (value hidden)")"

  if command -v nix >/dev/null 2>&1; then
    local feats
    feats="$(nix config show experimental-features 2>/dev/null || true)"
    [[ -n "$feats" ]] && row "effective features" "$feats"
  fi

  local leftovers=()
  local f
  for f in /etc/*.before-nix-darwin /etc/nix/*.before-nix-darwin; do
    [[ -e "$f" ]] && leftovers+=("$f")
  done
  ((${#leftovers[@]})) && row "pre-nix-darwin backups" "$(dim "${leftovers[*]} (safe to delete once happy)")"
  return 0
}

show_shell() {
  section "Shell"
  local parent login=""
  parent="$(ps -o comm= -p "$PPID" 2>/dev/null | tr -d ' ' || true)"
  [[ "$parent" == -* ]] && login=" (login shell)"
  parent="${parent#-}"
  row "running" "${parent##*/}${login}, nesting level $((${SHLVL:-1} - 1))"

  local zdot="${ZDOTDIR:-$HOME}"
  echo "  zsh reads these files, in order:"
  local f
  for f in /etc/zshenv "$HOME/.zshenv" "$zdot/.zshenv" \
    /etc/zprofile "$zdot/.zprofile" \
    /etc/zshrc "$zdot/.zshrc" "$HOME/.zshrc.local" \
    /etc/zlogin "$zdot/.zlogin"; do
    [[ "$f" == "$zdot/.zshenv" && "$zdot" == "$HOME" ]] && continue
    if [[ -e "$f" || -L "$f" ]]; then
      row "    $(tilde "$f")" "$(owner_of "$f")"
    fi
  done
  local stray
  for stray in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.bashrc" "$HOME/.bash_profile"; do
    if [[ "$zdot" != "$HOME" && -e "$stray" && ! -L "$stray" ]]; then
      row "    $(tilde "$stray")" "$(dim "ignored by zsh here (ZDOTDIR moved), likely a pre-nix leftover")"
    fi
  done
  return 0
}

show_session() {
  section "This session (layers on top of your system)"
  local any=""
  if [[ -n "${IN_NIX_SHELL:-}" ]]; then
    # `nix develop` exports the devshell's derivation name as $name.
    # shellcheck disable=SC2154
    local devshell="${name:-}"
    row "nix develop / nix-shell" "${IN_NIX_SHELL}${devshell:+, devshell \"$devshell\"}"
    any=1
  fi
  if [[ -n "${DIRENV_DIR:-}" ]]; then
    local direnv_dir="${DIRENV_DIR:-}"
    row "direnv" "active for $(tilde "${direnv_dir#-}")"
    case "${ISOLATE_MODE:-}" in
    isolated) row "isolation" "$(ok "isolated: flake + kept host tools + macOS base")" ;;
    bare) row "isolation" "$(ok "bare: flake + nix + macOS base")" ;;
    *) row "isolation" "inherit: flake layered on top of your full shell" ;;
    esac
    any=1
  fi
  local d dirs pkgs=()
  IFS=: read -ra dirs <<<"$PATH"
  for d in "${dirs[@]}"; do
    [[ "$d" == /nix/store/* ]] && pkgs+=("$(store_name "$d")")
  done
  if ((${#pkgs[@]})); then
    local shown="${pkgs[*]:0:8}"
    ((${#pkgs[@]} > 8)) && shown+=" … +$((${#pkgs[@]} - 8)) more"
    row "extra packages on PATH" "$shown"
    any=1
  fi
  [[ -z "$any" ]] && row "none" "$(dim "plain shell: only what ~/config installs")"
  return 0
}

show_path() {
  section "PATH (first match wins)"
  local d dirs i=0 seen=" "
  IFS=: read -ra dirs <<<"$PATH"
  for d in "${dirs[@]}"; do
    [[ -z "$d" || "$seen" == *" $d "* ]] && continue
    seen+="$d "
    [[ -d "$d" ]] || continue
    i=$((i + 1))
    row "$(printf '%2d. %s' "$i" "$(short "$d")")" "$(path_layer "$d")"
  done
}

show_here() {
  section "This folder"
  # Deepest context whose folder contains this one.
  if [[ -f /etc/config/contexts.json ]]; then
    local ctx
    # shellcheck disable=SC2016 # jq program, not shell
    ctx="$("$JQ" -r --arg pwd "$PWD/" --arg home "$HOME" '
      [ .[] | select(.directory as $d | $pwd | startswith($home + "/" + $d + "/")) ]
      | sort_by(.directory | length) | last // empty
      | "\(.name) (\(.path))"' /etc/config/contexts.json 2>/dev/null || true)"
    [[ -n "$ctx" ]] && row "context" "${ctx/$HOME/\~}"
  fi
  # Which git identity applies here (workspace/ picks it by folder).
  if "$GIT" rev-parse --git-dir >/dev/null 2>&1; then
    local email key signed
    email="$("$GIT" config user.email 2>/dev/null || echo "?")"
    key="$("$GIT" config user.signingKey 2>/dev/null || echo "")"
    signed="$("$GIT" config commit.gpgSign 2>/dev/null || echo false)"
    if [[ "$signed" == true ]]; then signed="$(ok "commits signed")"; else signed="$(warn "commits NOT signed")"; fi
    row "git identity" "$email, key ${key:+$(basename "$key")}  $signed"
  fi
  local dir="$PWD" found=""
  while [[ "$dir" != "/" ]]; do
    local f
    for f in flake.nix .envrc devenv.nix shell.nix; do
      if [[ -e "$dir/$f" ]]; then
        found+="$(tilde "$dir/$f")  "
      fi
    done
    [[ -n "$found" ]] && break
    dir="$(dirname "$dir")"
  done
  if [[ -z "$found" ]]; then
    row "project env" "$(dim "none (no flake.nix / .envrc here or above)")"
    return
  fi
  row "project files" "$found"
  if [[ -e "$dir/.envrc" ]]; then
    local line level="inherit"
    line="$(grep -E '^[[:space:]]*isolate([[:space:]]|$)' "$dir/.envrc" | head -1 || true)"
    if [[ "$line" == *--bare* ]]; then level="bare"; elif [[ -n "$line" ]]; then level="isolated"; fi
    row ".envrc level" "$level${line:+  $(dim "(${line#"${line%%[![:space:]]*}"})")}"
    local active="${DIRENV_DIR:-}"
    if [[ "${active#-}" == "$dir" ]]; then
      row "direnv" "$(ok "loaded")"
    else
      row "direnv" "$(warn "not loaded here; run \`direnv allow\` if you trust it")"
    fi
  fi
}

# ── config which <cmd> ────────────────────────────────────────────────────────
show_which() {
  local cmd="$1" p real i=0
  local paths=() dirs d seen=" "
  IFS=: read -ra dirs <<<"$PATH"
  for d in "${dirs[@]}"; do
    [[ -z "$d" || "$seen" == *" $d "* ]] && continue
    seen+="$d "
    [[ -x "$d/$cmd" && ! -d "$d/$cmd" ]] && paths+=("$d/$cmd")
  done
  if ((${#paths[@]} == 0)); then
    echo "$cmd: not found on PATH" >&2
    return 1
  fi
  for p in "${paths[@]}"; do
    i=$((i + 1))
    real="$("$REALPATH" "$p" 2>/dev/null || echo "$p")"
    local from
    case "$real" in
    /nix/store/*) from="$(store_name "$real")" ;;
    /opt/homebrew/Caskroom/*) from="Homebrew cask $(echo "${real#/opt/homebrew/Caskroom/}" | cut -d/ -f1)" ;;
    /opt/homebrew/Cellar/*) from="Homebrew formula $(echo "${real#/opt/homebrew/Cellar/}" | cut -d/ -f1)" ;;
    /Applications/*) from="app bundle $(echo "${real#/Applications/}" | cut -d/ -f1)" ;;
    *) from="$(tilde "$real")" ;;
    esac
    local tag
    if ((i == 1)); then tag="  $(ok "used")"; else tag="  $(dim "shadowed")"; fi
    printf '%s%s\n' "$(short "$p")" "$tag"
    row "  from" "$from"
    row "  layer" "$(path_layer "$(dirname "$p")")"
  done
}

# ── contexts ──────────────────────────────────────────────────────────────────
# Context repos (see ~/config/contexts/): the search list baked in from ~/config,
# adjusted per machine in $CONTEXTS_FILE (one path per line; `!path` turns a default off).

expand_path() {
  local p="$1"
  p="${p/#\~/$HOME}"
  [[ "$p" == /* ]] || p="$HOME/$p"
  printf '%s' "${p%/}"
}

# All candidate repo paths, in order, without duplicates.
context_candidates() {
  local -a list=() defaults=()
  local p line
  IFS=: read -ra defaults <<<"${CONTEXT_SEARCH:-}"
  for p in "${defaults[@]}"; do
    if [[ -n "$p" ]]; then list+=("$(expand_path "$p")"); fi
  done
  if [[ -f "$CONTEXTS_FILE" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%%#*}"
      line="${line//[[:space:]]/}"
      [[ -z "$line" ]] && continue
      if [[ "$line" == '!'* ]]; then
        local off kept=()
        off="$(expand_path "${line#!}")"
        for p in "${list[@]}"; do [[ "$p" == "$off" ]] || kept+=("$p"); done
        list=("${kept[@]}")
      else
        list+=("$(expand_path "$line")")
      fi
    done <"$CONTEXTS_FILE"
  fi
  local seen=" "
  for p in "${list[@]}"; do
    [[ "$seen" == *" $p "* ]] && continue
    seen+="$p "
    printf '%s\n' "$p"
  done
}

context_state() { # → active | missing | invalid
  local p="$1"
  if [[ ! -e "$p" ]]; then
    echo missing
  elif [[ -f "$p/flake.nix" && -e "$p/.git" && "$p" == "$HOME"/* && "$p" != *[[:space:]]* ]]; then
    echo active
  else
    echo invalid
  fi
}

active_contexts() {
  local p
  while IFS= read -r p; do
    if [[ "$(context_state "$p")" == active ]]; then printf '%s\n' "$p"; fi
  done < <(context_candidates)
}

# ~/Work/acme/config → "Work/acme" (the folder the context applies to)
context_directory() {
  local d
  d="$(dirname "$1")"
  printf '%s' "${d#"$HOME"/}"
}

# "Work/acme" → "work-acme"
context_default_name() {
  local d="$1"
  d="${d//\//-}"
  printf '%s' "$d" | tr '[:upper:]' '[:lower:]'
}

# The flake `config rebuild` actually builds: root + every active context.
write_wrapper() {
  local -a paths=()
  local p i=0
  mapfile -t paths < <(active_contexts)
  mkdir -p "$STATE_DIR"
  {
    echo "# Generated by 'config rebuild': ~/config plus the context repos found on this"
    echo "# machine. Regenerated on every build; do not edit."
    echo '{'
    echo '  inputs = {'
    echo "    root.url = \"git+file://$CONFIG_FLAKE\";"
    for p in "${paths[@]}"; do
      echo "    ctx$i.url = \"git+file://$p\";"
      echo "    ctx$i.inputs.nixpkgs.follows = \"root/nixpkgs\";"
      i=$((i + 1))
    done
    echo '  };'
    echo '  outputs ='
    echo '    inputs:'
    echo '    let'
    echo '      context = input: path: directory: name: {'
    echo '        inherit path directory;'
    echo '        name = input.context.name or name;'
    echo '        revision = input.rev or input.dirtyRev or "uncommitted";'
    echo '        hasShell = input ? devShells;'
    echo '        module = input.darwinModules.default or { };'
    echo '      };'
    echo '    in'
    echo '    {'
    echo "      darwinConfigurations.\"$CONFIG_SYSTEM\" = inputs.root.lib.mkSystem {"
    echo "        system = \"$CONFIG_SYSTEM\";"
    echo '        contexts = ['
    i=0
    for p in "${paths[@]}"; do
      local dir
      dir="$(context_directory "$p")"
      echo "          (context inputs.ctx$i \"$p\" \"$dir\" \"$(context_default_name "$dir")\")"
      i=$((i + 1))
    done
    echo '        ];'
    echo '      };'
    echo '    };'
    echo '}'
  } >"$STATE_DIR/flake.nix"
  # Always re-pin to the repos' current state.
  rm -f "$STATE_DIR/flake.lock"
}

# Revision a path was built from in the running system ("" if not part of it).
applied_revision() {
  local file="/etc/config/contexts.json"
  [[ -f "$file" ]] || return 0
  # shellcheck disable=SC2016 # jq program, not shell
  "$JQ" -r --arg p "$1" '.[] | select(.path == $p) | .revision' "$file" 2>/dev/null || true
}

show_contexts() {
  section "Contexts"
  local p any=""
  while IFS= read -r p; do
    any=1
    local state label
    state="$(context_state "$p")"
    label="$(tilde "$p")"
    case "$state" in
    missing) row "$label" "$(dim "not present")" ;;
    invalid) row "$label" "$(warn "needs a flake.nix, a git repo, a path under ~ without spaces")" ;;
    active)
      local head dirty="" applied now
      head="$("$GIT" -C "$p" rev-parse HEAD 2>/dev/null || echo "")"
      [[ -n "$("$GIT" -C "$p" status --porcelain 2>/dev/null)" ]] && dirty="-dirty"
      now="${head}${dirty}"
      applied="$(applied_revision "$p")"
      if [[ -z "$applied" ]]; then
        row "$label" "$(warn "found, not applied yet; run \`config rebuild\`")"
      elif [[ "$applied" == "$now" && -z "$dirty" ]]; then
        row "$label" "$(ok "applied @ ${head:0:7}")"
      elif [[ "$applied" == uncommitted ]]; then
        row "$label" "$(warn "applied from uncommitted files; commit the repo")"
      elif [[ -n "$dirty" ]]; then
        row "$label" "$(warn "applied @ ${applied:0:7}; repo has uncommitted changes")"
      else
        row "$label" "$(warn "applied @ ${applied:0:7}; repo is at ${head:0:7}, run \`config rebuild\`")"
      fi
      ;;
    esac
  done < <(context_candidates)
  [[ -n "$any" ]] || row "none" "$(dim "add one with \`config contexts add <path>\`")"
  row "machine-local list" "$(dim "$(tilde "$CONTEXTS_FILE") (not in git)")"
}

contexts_add() {
  local p
  p="$(expand_path "$1")"
  mkdir -p "$(dirname "$CONTEXTS_FILE")"
  touch "$CONTEXTS_FILE"
  local tmp
  tmp="$(mktemp)"
  grep -vxF "!$p" "$CONTEXTS_FILE" >"$tmp" || true
  mv "$tmp" "$CONTEXTS_FILE"
  # Re-enabling a default only needs the `!` line gone.
  context_candidates | grep -qxF "$p" || echo "$p" >>"$CONTEXTS_FILE"
  echo "Added $(tilde "$p") ($(context_state "$p")). Apply with \`config rebuild\`."
}

contexts_remove() {
  local p tmp
  p="$(expand_path "$1")"
  mkdir -p "$(dirname "$CONTEXTS_FILE")"
  touch "$CONTEXTS_FILE"
  tmp="$(mktemp)"
  grep -vxF "$p" "$CONTEXTS_FILE" >"$tmp" || true
  local d
  IFS=: read -ra defaults <<<"${CONTEXT_SEARCH:-}"
  for d in "${defaults[@]}"; do
    if [[ "$(expand_path "$d")" == "$p" ]] && ! grep -qxF "!$p" "$tmp"; then
      echo "!$p" >>"$tmp"
    fi
  done
  mv "$tmp" "$CONTEXTS_FILE"
  echo "Removed $(tilde "$p") from this machine's contexts. Apply with \`config rebuild\`."
}

context_new() {
  local p dir name f
  p="$(expand_path "$1")"
  if [[ "$p" != "$HOME"/* || "$p" == *[[:space:]]* ]]; then
    echo "A context must live under $HOME, in a path without spaces." >&2
    return 1
  fi
  if [[ -e "$p/flake.nix" ]]; then
    echo "$(tilde "$p") already has a flake.nix; not touching it." >&2
    return 1
  fi
  dir="$(context_directory "$p")"
  name="$(context_default_name "$dir")"
  mkdir -p "$p"
  for f in flake.nix module.nix README.md; do
    sed -e "s|@NAME@|$name|g" -e "s|@DIRECTORY@|$dir|g" "$CONTEXT_TEMPLATE/$f" >"$p/$f"
  done
  printf '.direnv/\nresult\n' >"$p/.gitignore"
  "$GIT" -C "$p" init -q -b main 2>/dev/null || "$GIT" -C "$p" init -q
  "$GIT" -C "$p" add -A
  if ! context_candidates | grep -qxF "$p"; then
    contexts_add "$p" >/dev/null
  fi
  cat <<NEXT
Created context "$name" in $(tilde "$p") (applies to ~/$dir), files staged in git.

  1. Edit $(tilde "$p")/module.nix (apps, git identity, agent instructions)
     and flake.nix (shell layer for ~/$dir).
  2. config rebuild
  3. cd $(tilde "$p") && git commit -m "feat: initial $name context"
NEXT
}

# ── applying changes ──────────────────────────────────────────────────────────
# Build as you so ~/config/.git stays yours (a fully sudo'd switch leaves root-owned
# git objects behind), then use sudo only to record the generation and activate it.
build() {
  cd "$CONFIG_FLAKE"
  local flake=".#$CONFIG_SYSTEM" active
  active="$(active_contexts)"
  if [[ -n "$active" ]]; then
    write_wrapper
    flake="$STATE_DIR#$CONFIG_SYSTEM"
    echo "contexts: $(while IFS= read -r p; do printf '%s ' "$(tilde "$p")"; done <<<"$active")"
  fi
  darwin-rebuild build --flake "$flake" "$@"
}

cmd_rebuild() {
  build "$@"
  local system nix_env
  system="$("$REALPATH" result)"
  nix_env="$(command -v nix-env)"
  echo "activating $system"
  sudo -H "$nix_env" --profile "$SYSTEM_PROFILE" --set "$system"
  sudo -H "$system/activate"
}

cmd_signing() {
  if ! command -v git-signers >/dev/null 2>&1; then
    echo "git-signers isn't installed yet; run \`config rebuild\` first." >&2
    exit 1
  fi
  case "${1:-status}" in
  status | upload) git-signers "${1:-status}" ;;
  *) usage ;;
  esac
}

cmd_check() {
  build "$@"
  "$NVD" diff "$CURRENT_SYSTEM" "$CONFIG_FLAKE/result"
}

cmd_update() {
  nix flake update --flake "$CONFIG_FLAKE" "$@"
  echo "Inputs updated. Review with 'config check', apply with 'config rebuild', then commit flake.lock."
}

cmd_rollback() {
  sudo -H "$(command -v darwin-rebuild)" --rollback "$@"
}

cmd_generations() {
  darwin-rebuild --list-generations "$@"
}

cmd_edit() {
  if command -v zed >/dev/null 2>&1; then
    zed "$CONFIG_FLAKE"
  else
    "${EDITOR:-vi}" "$CONFIG_FLAKE"
  fi
}

usage() {
  cat <<USAGE
config: the entry point for this machine's setup ($(tilde "$CONFIG_FLAKE"))

  config                 status: what's shaping this shell, and where it comes from
  config which <cmd>     where a command comes from, and what it shadows
  config rebuild [args]  apply $(tilde "$CONFIG_FLAKE") (Touch ID); args go to the build, e.g. -L
  config check [args]    build without applying and show what would change
  config update          update pinned inputs; then check, rebuild, commit flake.lock
  config rollback        go back to the previous system generation
  config generations     list system generations
  config edit            open $(tilde "$CONFIG_FLAKE") in the editor
  config contexts        list context repos and what's applied
  config contexts add <path> | remove <path>
                         change this machine's list (kept in $(tilde "$CONTEXTS_FILE"), not git)
  config context new <path>
                         create a context repo, e.g. ~/Work/config (applies to ~/Work)
  config signing         this Mac's git signing keys and whether GitHub has them
  config signing upload  add this Mac's keys to GitHub (for "Verified")
  config help            this text
USAGE
}

cmd="${1:-}"
[[ $# -gt 0 ]] && shift
case "$cmd" in
"")
  printf '%sconfig%s %s\n' "$B" "$R" "$(dim "· what's shaping this shell (values of env vars are never shown)")"
  show_system
  show_contexts
  show_home
  show_nix
  show_shell
  show_session
  show_path
  show_here
  echo
  ;;
which)
  [[ -n "${1:-}" ]] || {
    usage
    exit 1
  }
  show_which "$1"
  ;;
rebuild) cmd_rebuild "$@" ;;
check) cmd_check "$@" ;;
update) cmd_update "$@" ;;
rollback) cmd_rollback "$@" ;;
generations) cmd_generations "$@" ;;
edit) cmd_edit ;;
signing) cmd_signing "$@" ;;
contexts)
  case "${1:-}" in
  "") show_contexts ;;
  add) if [[ -n "${2:-}" ]]; then contexts_add "$2"; else usage; fi ;;
  remove | rm) if [[ -n "${2:-}" ]]; then contexts_remove "$2"; else usage; fi ;;
  *) usage ;;
  esac
  ;;
context)
  if [[ "${1:-}" == new && -n "${2:-}" ]]; then context_new "$2"; else usage; fi
  ;;
help | -h | --help) usage ;;
*)
  usage
  exit 1
  ;;
esac
