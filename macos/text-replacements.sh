# text-replacements <entries.tsv>: make macOS's own Text Replacements (System Settings →
# Keyboard → Text Replacements) include the declared ones. One `shortcut<TAB>phrase` per
# line. Packaged by macos/text-replacements.nix and run on every rebuild.
#
# Current macOS has no `defaults` key for these: they live in a Core Data store that the
# `kbd` daemon reads (and syncs through iCloud). This upserts the declared entries,
# deletes ones that were declared last time but aren't anymore, leaves anything you added
# by hand alone, and restarts `kbd` only when something changed. Never fails a rebuild.
DB="${TEXT_REPLACEMENTS_DB:-$HOME/Library/KeyboardServices/TextReplacements.db}"
STATE="${TEXT_REPLACEMENTS_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/config/text-replacements.tsv}"
entries="$1"

warn() { echo "text-replacements: $*" >&2; }
lit() { printf "'%s'" "${1//\'/\'\'}"; } # SQL string literal

if [[ ! -f "$DB" ]]; then
  warn "no $DB yet; open System Settings → Keyboard → Text Replacements once, then rebuild."
  exit 0
fi
if ! sqlite3 -batch "$DB" "SELECT 1 FROM ZTEXTREPLACEMENTENTRY LIMIT 1;" >/dev/null 2>&1; then
  warn "can't read $DB (unexpected format, or no access); skipped."
  exit 0
fi

now="(CAST(strftime('%s','now') AS REAL) - 978307200)" # Core Data dates count from 2001
uuid="(SELECT substr(u,1,8)||'-'||substr(u,9,4)||'-'||substr(u,13,4)||'-'||substr(u,17,4)||'-'||substr(u,21) FROM (SELECT upper(hex(randomblob(16))) AS u))"
active="SELECT 1 FROM ZTEXTREPLACEMENTENTRY WHERE ZWASDELETED = 0 AND ZSHORTCUT ="

sql=".timeout 5000
BEGIN;"
while IFS=$'\t' read -r shortcut phrase; do
  [[ -n "$shortcut" ]] || continue
  s="$(lit "$shortcut")" p="$(lit "$phrase")"
  sql+="
UPDATE ZTEXTREPLACEMENTENTRY SET ZPHRASE = $p, Z_OPT = Z_OPT + 1, ZNEEDSSAVETOCLOUD = 1, ZTIMESTAMP = $now
  WHERE ZWASDELETED = 0 AND ZSHORTCUT = $s AND ZPHRASE <> $p;
UPDATE Z_PRIMARYKEY SET Z_MAX = Z_MAX + 1
  WHERE Z_NAME = 'TextReplacementEntry' AND NOT EXISTS ($active $s);
INSERT INTO ZTEXTREPLACEMENTENTRY
  (Z_PK, Z_ENT, Z_OPT, ZNEEDSSAVETOCLOUD, ZWASDELETED, ZTIMESTAMP, ZPHRASE, ZSHORTCUT, ZUNIQUENAME, ZREMOTERECORDINFO)
  SELECT Z_MAX, Z_ENT, 1, 1, 0, $now, $p, $s, $uuid, NULL FROM Z_PRIMARYKEY
  WHERE Z_NAME = 'TextReplacementEntry' AND NOT EXISTS ($active $s);"
done <"$entries"

# Declared last time, gone now: delete (the way macOS does, so the deletion syncs too).
if [[ -f "$STATE" ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    if ! grep -qxF -- "$line" "$entries"; then
      s="$(lit "${line%%$'\t'*}")" p="$(lit "${line#*$'\t'}")"
      sql+="
UPDATE ZTEXTREPLACEMENTENTRY SET ZWASDELETED = 1, Z_OPT = Z_OPT + 1, ZNEEDSSAVETOCLOUD = 1, ZTIMESTAMP = $now
  WHERE ZWASDELETED = 0 AND ZSHORTCUT = $s AND ZPHRASE = $p;"
    fi
  done <"$STATE"
fi

sql+="
SELECT total_changes();
COMMIT;"

if ! changes="$(sqlite3 -batch "$DB" <<<"$sql" 2>&1)"; then
  warn "couldn't update $DB: $changes"
  exit 0
fi
mkdir -p "$(dirname "$STATE")"
cp "$entries" "$STATE"
chmod u+w "$STATE"
if [[ "${changes##*$'\n'}" != 0 ]]; then
  killall kbd 2>/dev/null || true # restarts on its own and rereads the store
  echo "text-replacements: updated macOS Text Replacements"
fi
