# git-signers: this Mac's git signing keys. Packaged by workspace/default.nix, which
# injects PROFILES, EMAIL, KEY, GITHUB, WHERE (folder under ~, "" for everywhere) and
# ALLOWED. `config signing` is the usual way in.
#
#   git-signers           write allowed_signers: this Mac's keys only (runs on every rebuild)
#   git-signers status    each profile's key on this Mac, and whether GitHub has it
#   git-signers upload    add this Mac's keys to GitHub (with gh) where they're missing
#
# Each Mac signs with its own key per profile and trusts only its own keys locally.
# Commits from your other Macs are verified by GitHub ("Verified"), which is why each
# Mac's key is uploaded there. Nothing is downloaded or cached.
GITHUB_API="${GITHUB_API:-https://api.github.com}"

# "ssh-ed25519 AAAA…" for a profile's key on this Mac ("" if it doesn't exist yet).
pub() {
  if [[ -f "${KEY[$1]}.pub" ]]; then cut -d' ' -f1,2 "${KEY[$1]}.pub"; fi
}

# Public signing keys GitHub lists for an account, read live (not stored anywhere).
github_keys() {
  curl -fsSL --max-time 10 -H 'Accept: application/vnd.github+json' \
    "$GITHUB_API/users/$1/ssh_signing_keys?per_page=100" 2>/dev/null |
    jq -r '.[].key' | cut -d' ' -f1,2
}

# → yes | no | unknown (offline)
on_github() {
  local k keys
  k="$(pub "$1")"
  [[ -n "$k" ]] || {
    echo no
    return
  }
  if ! keys="$(github_keys "${GITHUB[$1]}")"; then
    echo unknown
  elif grep -qxF "$k" <<<"$keys"; then
    echo yes
  else
    echo no
  fi
}

write() {
  local p k tmp
  mkdir -p "$(dirname "$ALLOWED")"
  tmp="$(mktemp)"
  for p in "${PROFILES[@]}"; do
    k="$(pub "$p")"
    if [[ -n "$k" ]]; then printf '%s namespaces="git" %s\n' "${EMAIL[$p]}" "$k"; fi
  done | sort -u >"$tmp"
  mv "$tmp" "$ALLOWED"
}

status() {
  local p state
  for p in "${PROFILES[@]}"; do
    printf '%s (%s, %s)\n' "$p" "${WHERE[$p]:+~/}${WHERE[$p]:-everywhere}" "${EMAIL[$p]}"
    if [[ -f "${KEY[$p]}" ]]; then
      printf '  key on this Mac    %s\n' "$(ssh-keygen -lf "${KEY[$p]}.pub" | cut -d' ' -f2)"
    else
      echo "  key on this Mac    not created yet (run \`config rebuild\`)"
    fi
    if [[ -z "${GITHUB[$p]}" ]]; then
      state="no GitHub account set (\`github\` in its profile)"
    else
      case "$(on_github "$p")" in
      yes) state="✓ on github.com/${GITHUB[$p]}" ;;
      no) state="! not on github.com/${GITHUB[$p]}; run \`config signing upload\`" ;;
      *) state="couldn't reach GitHub" ;;
      esac
    fi
    printf '  GitHub             %s\n' "$state"
  done
}

upload() {
  local p u login title found
  login="$(gh api user --jq .login 2>/dev/null || true)"
  for p in "${PROFILES[@]}"; do
    u="${GITHUB[$p]}"
    [[ -n "$u" && -f "${KEY[$p]}.pub" ]] || continue
    found="$(on_github "$p")"
    if [[ "$found" == yes ]]; then
      echo "\"$p\": already on github.com/$u"
      continue
    fi
    if [[ "$login" != "$u" ]]; then
      echo "\"$p\" belongs to github.com/$u, but gh is logged in as ${login:-nobody}."
      echo "  gh auth login (or gh auth switch -u $u), then run this again."
      continue
    fi
    title="$(scutil --get ComputerName 2>/dev/null || hostname -s) ($p)"
    echo "Adding this Mac's \"$p\" key to github.com/$u as a signing key: $title"
    if ! gh ssh-key add "${KEY[$p]}.pub" --type signing --title "$title"; then
      echo "  If that was a permissions error: gh auth refresh -h github.com -s admin:ssh_signing_key" >&2
    fi
  done
}

case "${1:-write}" in
write) write ;;
status) status ;;
upload) upload ;;
*)
  echo "usage: git-signers [write | status | upload]" >&2
  exit 1
  ;;
esac
