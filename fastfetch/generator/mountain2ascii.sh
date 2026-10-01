#!/usr/bin/env bash
# mountain2ascii.sh — turn a real (horizontal) photo of a mountain into a fastfetch logo
#
# Only landscape photos are used (width/height between MIN_RATIO and MAX_RATIO).
# If Wikipedia's lead photo is vertical, it searches Wikimedia Commons for a horizontal one.
#
# If the title isn't an exact Wikipedia page (or redirects elsewhere), it lists the closest
# matches and asks which to use; 0 keeps your name as typed. Without a terminal (build-all.sh)
# it takes the first match.
#
# Usage:
#   ./mountain2ascii.sh "Kangchenjunga"
#   ./mountain2ascii.sh "Kangchenjunga" --pick 3          # 3rd horizontal Commons result instead
#   ./mountain2ascii.sh "Matterhorn" --image "https://commons.wikimedia.org/wiki/File:X.jpg"
#   ./mountain2ascii.sh --help
#
# Options:
#   --image  URL|PATH     Use this photo (rejected if it isn't horizontal)
#   --pick   N            Skip the lead photo; use the Nth horizontal photo from a Commons search
#   --crop   GRAV:WxH     Optional crop, e.g. north:70%x60% (needs ImageMagick)
#   --style  STYLE        sextant | blocks | braille | ascii | color-ascii   (default: sextant)
#   --size   WxH          Max logo size in terminal cells           (default: 70x45)
#   --elev   METRES       Override the elevation
#   --out    DIR          Output folder (default: ~/.config/fastfetch/mountains)
#   --keep                Keep the downloaded image so you can compare
#
# Needs: curl, jq, chafa.  Optional: ImageMagick (magick).

set -euo pipefail

MIN_RATIO=1.2    # at least 1.2× wider than tall
MAX_RATIO=2.4    # skip ultra-wide panoramas (they come out as a thin strip)
THUMB_W=1280     # download width in px

usage() { awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; }
case "${1:-}" in
  ""|-h|--help) usage; exit 0 ;;
esac
TITLE="$1"; shift
IMAGE="" PICK="" CROP="" STYLE="sextant" SIZE="70x45" KEEP=0 ELEV_OVERRIDE=""
OUT="$HOME/.config/fastfetch/mountains"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) IMAGE="$2"; shift 2 ;;
    --pick)  PICK="$2";  shift 2 ;;
    --crop)  CROP="$2";  shift 2 ;;
    --style) STYLE="$2"; shift 2 ;;
    --size)  SIZE="$2";  shift 2 ;;
    --elev)  ELEV_OVERRIDE="${2//,/}"; shift 2 ;;
    --out)   OUT="$2";   shift 2 ;;
    --keep)  KEEP=1;     shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

for dep in curl jq chafa; do
  command -v "$dep" >/dev/null || { echo "Missing: $dep  (brew install $dep)" >&2; exit 1; }
done

UA="fastfetch-mountains/1.0 (personal terminal rice; https://github.com/fastfetch-cli/fastfetch)"
mkdir -p "$OUT"
TMP="$(mktemp -d)"; trap '[[ $KEEP == 1 ]] || rm -rf "$TMP"' EXIT

log() { echo "$*" >&2; }

get() {  # GET url [curl args...]; prints body or logs HTTP status and returns 1
  local url="$1"; shift; local code
  code="$(curl -sSL -A "$UA" -o "$TMP/body" -w '%{http_code}' "$@" "$url")" || { log "Network error: $url"; return 1; }
  [[ "$code" == 2* ]] || { log "HTTP $code from: $url"; return 1; }
  cat "$TMP/body"
}

urldecode() { local s="${1//+/ }"; printf '%b' "${s//%/\\x}"; }

is_horizontal() {  # W H
  awk -v w="$1" -v h="$2" -v lo="$MIN_RATIO" -v hi="$MAX_RATIO" \
      'BEGIN{ r = (h>0) ? w/h : 0; exit !(r>=lo && r<=hi) }'
}

wikimedia_file_name() {  # any Wikimedia link -> file name, or return 1
  local u="${1%%[?#]*}"
  case "$u" in
    *wikimedia.org/wiki/File:*|*wikipedia.org/wiki/File:*) urldecode "${u##*/wiki/File:}" ;;
    *upload.wikimedia.org/*/thumb/*) local d="${u%/*}"; urldecode "${d##*/}" ;;
    *upload.wikimedia.org/*)         urldecode "${u##*/}" ;;
    *) return 1 ;;
  esac
}

commons_info() {  # file name -> "W H THUMB_URL"
  local file="$1" api out
  for api in https://commons.wikimedia.org/w/api.php https://en.wikipedia.org/w/api.php; do
    out="$(get "$api" -G --data-urlencode action=query --data-urlencode format=json \
            --data-urlencode prop=imageinfo --data-urlencode "iiprop=url|size" \
            --data-urlencode "iiurlwidth=$THUMB_W" --data-urlencode "titles=File:$file" 2>/dev/null \
          | jq -r '.query.pages[]?.imageinfo[0]? | select(.width) | "\(.width) \(.height) \(.thumburl // .url)"' \
          2>/dev/null | head -n 1)" || true
    [[ -n "$out" ]] && { echo "$out"; return 0; }
  done
  return 1
}

commons_search_horizontal() {  # name, n -> "W H THUMB_URL" of the Nth horizontal photo
  local name="$1" n="${2:-1}"
  get "https://commons.wikimedia.org/w/api.php" -G \
      --data-urlencode action=query --data-urlencode format=json \
      --data-urlencode generator=search --data-urlencode gsrnamespace=6 --data-urlencode gsrlimit=50 \
      --data-urlencode "gsrsearch=$name filetype:bitmap -map -diagram -svg" \
      --data-urlencode prop=imageinfo --data-urlencode "iiprop=url|size|mime" \
      --data-urlencode "iiurlwidth=$THUMB_W" 2>/dev/null \
  | jq -r --argjson lo "$MIN_RATIO" --argjson hi "$MAX_RATIO" --argjson n "$n" '
      [ .query.pages // {} | .[] ] | sort_by(.index)
      | map(.imageinfo[0]? // empty
            | select(.mime == "image/jpeg" or .mime == "image/png")
            | select(.height > 0 and (.width/.height) >= $lo and (.width/.height) <= $hi))
      | .[$n-1] // empty | "\(.width) \(.height) \(.thumburl // .url)"'
}

local_dims() {  # file -> "W H"
  if command -v sips >/dev/null; then
    sips -g pixelWidth -g pixelHeight "$1" 2>/dev/null | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w, h}'
  elif command -v magick >/dev/null; then
    magick identify -format '%w %h' "$1[0]"
  fi
}

# ---------- 1. Wikipedia page (search fallback if the exact title 404s)
summary_for() { get "https://en.wikipedia.org/api/rest_v1/page/summary/$(jq -rn --arg t "${1// /_}" '$t|@uri')" 2>/dev/null; }
same_title() { [[ "$(tr '[:upper:]_' '[:lower:] ' <<<"$1")" == "$(tr '[:upper:]_' '[:lower:] ' <<<"$2")" ]]; }

# Ask which match to use. Only when run from a terminal; build-all.sh (no tty) keeps the first match.
# Prints the chosen title, or nothing to use the name as typed.
choose_match() {  # candidate titles...
  if ! [[ -t 0 && -t 2 ]]; then log "Using closest match: $1"; echo "$1"; return; fi
  local i=1 t ans
  log "Closest matches for \"$TITLE\":"
  for t in "$@"; do log "  $i) $t"; i=$((i+1)); done
  log "  0) none — use \"$TITLE\" as typed (no Wikipedia photo/elevation; use --elev / --image)"
  while true; do
    read -r -p "Pick [1]: " ans </dev/tty >&2; ans="${ans:-1}"
    [[ "$ans" == 0 ]] && return
    [[ "$ans" =~ ^[0-9]+$ ]] && (( ans <= $# )) && { echo "${!ans}"; return; }
    log "Type a number from 0 to $#"
  done
}

NAME="$TITLE" QID="" SUMMARY=""
if SUMMARY="$(summary_for "$TITLE")"; then
  # Wikipedia redirected to a different page (e.g. "El Cap" → "El Capitan"): confirm it.
  RESOLVED="$(jq -r '.title' <<<"$SUMMARY")"
  if ! same_title "$RESOLVED" "$TITLE"; then
    log "Wikipedia redirects \"$TITLE\" to \"$RESOLVED\"."
    [[ -n "$(choose_match "$RESOLVED")" ]] || SUMMARY=""
  fi
else
  log "No page titled \"$TITLE\" — searching Wikipedia…"
  FOUND=()
  while IFS= read -r t; do [[ -n "$t" ]] && FOUND+=("$t"); done < <(
    get "https://en.wikipedia.org/w/api.php" -G --data-urlencode action=query \
        --data-urlencode list=search --data-urlencode format=json --data-urlencode srlimit=5 \
        --data-urlencode "srsearch=$TITLE mountain" 2>/dev/null | jq -r '.query.search[].title' || true)
  PICKED=""
  [[ ${#FOUND[@]} -gt 0 ]] && PICKED="$(choose_match "${FOUND[@]}")"
  if [[ -n "$PICKED" ]] && SUMMARY="$(summary_for "$PICKED")"; then :
  else SUMMARY=""; log "Not using Wikipedia; using \"$TITLE\" as the name"; fi
fi
if [[ -n "$SUMMARY" ]]; then
  NAME="$(jq -r '.title' <<<"$SUMMARY")"
  QID="$(jq -r '.wikibase_item // empty' <<<"$SUMMARY")"
  log "Wikipedia: $NAME — $(jq -r '.description // "no description"' <<<"$SUMMARY")"
fi

# ---------- 2. Choose a horizontal photo
PHOTO="" W="" H=""
if [[ -n "$IMAGE" && -f "${IMAGE/#\~/$HOME}" ]]; then
  cp "${IMAGE/#\~/$HOME}" "$TMP/src"; read -r W H <<<"$(local_dims "$TMP/src")"
elif [[ -n "$IMAGE" ]]; then
  if FILE="$(wikimedia_file_name "$IMAGE")"; then
    INFO="$(commons_info "$FILE")" || { log "Wikimedia doesn't know a file called \"$FILE\""; exit 1; }
    read -r W H PHOTO <<<"$INFO"
  else
    PHOTO="$IMAGE"
  fi
else
  if [[ -z "$PICK" && -n "$SUMMARY" ]]; then
    LEAD="$(jq -r '.originalimage.source // empty' <<<"$SUMMARY")"
    LW="$(jq -r '.originalimage.width // 0' <<<"$SUMMARY")"; LH="$(jq -r '.originalimage.height // 0' <<<"$SUMMARY")"
    if [[ -n "$LEAD" ]] && is_horizontal "$LW" "$LH"; then
      FILE="$(wikimedia_file_name "$LEAD")" && INFO="$(commons_info "$FILE")" && read -r W H PHOTO <<<"$INFO"
      [[ -z "$PHOTO" ]] && { PHOTO="$LEAD" W="$LW" H="$LH"; }
      log "Using Wikipedia's lead photo"
    elif [[ -n "$LEAD" ]]; then
      log "Lead photo is vertical (${LW}×${LH}) — searching Commons for a horizontal one…"
    fi
  fi
  if [[ -z "$PHOTO" ]]; then
    INFO="$(commons_search_horizontal "$NAME" "${PICK:-1}")" || true
    [[ -z "$INFO" ]] && { log "No horizontal photo found for \"$NAME\" (pick ${PICK:-1}). Try --image"; exit 1; }
    read -r W H PHOTO <<<"$INFO"
    log "Using Commons search result #${PICK:-1}"
  fi
fi

if [[ -n "$PHOTO" ]]; then
  log "Image: $PHOTO"
  get "$PHOTO" > "$TMP/src" || { log "Couldn't download the image"; exit 1; }
  [[ -z "$W" ]] && read -r W H <<<"$(local_dims "$TMP/src")"
fi
if [[ -n "$W" ]] && ! is_horizontal "$W" "$H"; then
  log "That photo is ${W}×${H} — not horizontal (needs width/height ${MIN_RATIO}–${MAX_RATIO}). Pick another."
  exit 1
fi
log "Photo size: ${W:-?}×${H:-?}"
SRC="$TMP/src"

# ---------- 3. Elevation from Wikidata (P2044), metres
ELEV_M=""
if [[ -n "$QID" ]] && WD="$(get "https://www.wikidata.org/wiki/Special:EntityData/$QID.json" 2>/dev/null)"; then
  ELEV_M="$(jq -r --arg q "$QID" '
    .entities[$q].claims.P2044[0].mainsnak.datavalue.value
    | if . == null then empty else
        (.amount|tonumber) * (if (.unit|endswith("Q3710")) then 0.3048 else 1 end) end' <<<"$WD")"
fi
[[ -n "$ELEV_OVERRIDE" ]] && ELEV_M="$ELEV_OVERRIDE"
log "Elevation: ${ELEV_M:-unknown} m"

# ---------- 4. Prep + convert
if command -v magick >/dev/null; then
  CROP_ARGS=()
  [[ -n "$CROP" ]] && CROP_ARGS=(-gravity "${CROP%%:*}" -crop "${CROP#*:}+0+0" +repage)
  magick "$SRC[0]" -auto-orient -colorspace sRGB ${CROP_ARGS[@]+"${CROP_ARGS[@]}"} \
         -sigmoidal-contrast 4x50% -unsharp 0x1 "$TMP/prep.png"
  SRC="$TMP/prep.png"
elif [[ -n "$CROP" ]]; then
  log "Note: --crop needs ImageMagick (brew install imagemagick); skipping crop"
fi

case "$STYLE" in
  sextant)     ARGS=(--symbols sextant+block+space --colors full) ;;
  blocks)      ARGS=(--symbols block+border --colors full) ;;
  braille)     ARGS=(--symbols braille --colors full --fg-only) ;;
  ascii)       ARGS=(--symbols ascii   --colors none) ;;
  color-ascii) ARGS=(--symbols ascii   --colors full --fg-only) ;;
  *) log "Unknown style: $STYLE"; exit 1 ;;
esac
ART="$(chafa --format symbols --size "$SIZE" --work 9 "${ARGS[@]}" "$SRC" | sed -E $'s/\x1b\\[\\?25[hl]//g')"

# ---------- 5. One-line caption, centred:   MATTERHORN ─ ▲ 4,478 m · 14,692 ft
fmt() { awk -v n="$1" 'BEGIN{ n=int(n+0.5); s=sprintf("%d",n); r="";
         while (length(s)>3){ r=","substr(s,length(s)-2) r; s=substr(s,1,length(s)-3)} print s r }'; }
B=$'\e[1;37m' A=$'\e[0;36m' D=$'\e[0;90m' R=$'\e[0m'
UPPER="$(tr '[:lower:]' '[:upper:]' <<<"$NAME")"
PLAIN="$UPPER"; CAPTION="${B}${UPPER}${R}"
if [[ -n "$ELEV_M" ]]; then
  M="$(fmt "$ELEV_M")"; FT="$(fmt "$(awk -v m="$ELEV_M" 'BEGIN{print m*3.28084}')")"
  PLAIN+=" ─ ▲ $M m · $FT ft"
  CAPTION+=" ${D}─${R} ${A}▲ $M m${R} ${D}· $FT ft${R}"
fi
FIRST_LINE="${ART%%$'\n'*}"
ART_W="$(sed -E $'s/\x1b\\[[0-9;]*m//g' <<<"$FIRST_LINE" | LC_ALL=en_US.UTF-8 wc -m)"
CAP_W="$(printf '%s' "$PLAIN" | LC_ALL=en_US.UTF-8 wc -m)"
PAD=$(( (ART_W - 1 - CAP_W) / 2 )); (( PAD < 0 )) && PAD=0
CAPTION="$(printf '%*s' "$PAD" '')$CAPTION"

SLUG="$(tr '[:upper:]' '[:lower:]' <<<"$NAME" | tr -cs 'a-z0-9' '-' | sed 's/-$//')"
printf '%s%s\n%s\n' "$ART" "$R" "$CAPTION" > "$OUT/$SLUG.txt"

cat "$OUT/$SLUG.txt"
echo; echo "Saved → $OUT/$SLUG.txt"
if [[ $KEEP == 1 ]]; then echo "Image kept at $TMP"; fi
exit 0