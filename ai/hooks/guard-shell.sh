# Shared pre-shell-command guard for every AI agent.
# Packaged by ai/default.nix as `ai-guard-shell <claude|codex>`.
#
# Input (stdin, JSON): Claude / Codex PreToolUse, {"tool_input": {"command": "..."}, ...}
# Output: exit 2 + reason on stderr blocks; exit 0 allows.
#
# Add a rule: append a "regex|reason" line to RULES. Test it:
#   echo '{"tool_input":{"command":"git push --force"}}' | ai-guard-shell claude; echo $?

# $1 names the calling agent (claude|codex); both speak the same protocol.
input="$(cat)"
cmd="$(jq -r '.tool_input.command // .command // empty' <<<"$input")"

# Patterns are regexes, so `$` is literal on purpose.
# shellcheck disable=SC2016
RULES=(
  '(^|[;&|[:space:]])rm[[:space:]]+-[a-zA-Z]*[rR][a-zA-Z]*[[:space:]]+(/|~|\$HOME)/?([[:space:]]|$)|Recursive delete of / or your home directory'
  'git[[:space:]]+push([[:space:]].*)?[[:space:]](--force([[:space:]]|$)|-f([[:space:]]|$))|Force push; use --force-with-lease instead'
  '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z)?sh([[:space:]]|$)|Piping a download straight into a shell'
  '(^|[;&|[:space:]])(brew[[:space:]]+(install|reinstall)|npm[[:space:]]+(i|install)[[:space:]]+(-g|--global))([[:space:]]|$)|Ad-hoc global install; add it to ~/config instead (see the nix-config skill)'
  '(^|[;&|[:space:]])op[[:space:]]+(read|item[[:space:]]+get)|Reading secrets from 1Password; ask the user to do this'
  '(^|[;&|[:space:]])git[[:space:]].*(--no-gpg-sign|(commit|tag)\.[gG][pP][gG][sS][iI][gG][nN]([[:space:]]+|=)(false|no|off|0))|Unsigned commits are not allowed on this machine'
)

reason=""
for rule in "${RULES[@]}"; do
  pattern="${rule%|*}"
  if [[ "$cmd" =~ $pattern ]]; then
    reason="${rule##*|}"
    break
  fi
done

if [[ -n "$reason" ]]; then
  echo "Blocked by ai-guard-shell: $reason" >&2
  exit 2
fi
exit 0
