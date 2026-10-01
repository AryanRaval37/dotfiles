#!/usr/bin/env bash
# build-all.sh — build a logo for every mountain in one or more list files
#
# Usage:
#   ./build-all.sh [LIST...] [options for mountain2ascii.sh]
#   ./build-all.sh --out ~/mountain-test
#   ./build-all.sh mountains.list --out ~/mountain-test --style braille
#
# With no list given, uses mountains.list next to this script.
# List line format:   Wikipedia title | image URL or path | crop | elevation m   (last three optional)
# Failures are written to build-errors.log in the current folder (removed when nothing fails).

case "${1:-}" in
  -h|--help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONVERT="$SCRIPT_DIR/mountain2ascii.sh"

LISTS=()
while [[ $# -gt 0 && "$1" != --* ]]; do
  [[ -f "$1" ]] || { echo "List not found: $1" >&2; exit 1; }
  LISTS+=("$1"); shift
done
[[ ${#LISTS[@]} -eq 0 ]] && LISTS=("$SCRIPT_DIR/mountains.list")

trim() { local s="${1%%#*}"; s="${s#"${s%%[![:space:]]*}"}"; printf '%s' "${s%"${s##*[![:space:]]}"}"; }
LOG="$PWD/build-errors.log"; : > "$LOG"
ok=0 failed=0

for LIST in "${LISTS[@]}"; do
  echo "── $(basename "$LIST")"
  while IFS='|' read -r title img crop elev || [[ -n "$title" ]]; do
    title="$(trim "$title")"; img="$(trim "$img")"; crop="$(trim "$crop")"; elev="$(trim "$elev")"
    [[ -z "$title" ]] && continue
    opts=()
    [[ -n "$img"  ]] && opts+=(--image "$img")
    [[ -n "$crop" ]] && opts+=(--crop "$crop")
    [[ -n "$elev" ]] && opts+=(--elev "$elev")
    printf '==> %-24s ' "$title"
    if err="$("$CONVERT" "$title" ${opts[@]+"${opts[@]}"} "$@" 2>&1 >/dev/null </dev/null)"; then
      echo ok; ok=$((ok+1))
    else
      echo "FAILED: ${err##*$'\n'}"; failed=$((failed+1))
      printf '### %s  (%s)\n%s\n\n' "$title" "$(basename "$LIST")" "$err" >> "$LOG"
    fi
  done < "$LIST"
done

echo "Done: $ok ok, $failed failed"
if [[ -s "$LOG" ]]; then echo "Error details: $LOG"; else rm -f "$LOG"; fi
exit 0
