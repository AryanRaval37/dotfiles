#!/usr/bin/env bash
# Browse the fastfetch mountain art. Only "delete" changes anything, and it moves files to the Trash.
#   ./review.sh            fuzzy-pick with live preview (fzf)
#   ./review.sh all        page through every file, one at a time (d = move to Trash)
#   ./review.sh k2         show one file (name without .txt)
#   ./review.sh ff k2      run fastfetch with that specific mountain
#   ./review.sh DIR [...]  same as above, but for another folder, e.g. ./review.sh ./test-out all
DIR="${MOUNTAINS_DIR:-$HOME/.config/fastfetch/mountains}"
if [ -d "$1" ]; then DIR="${1%/}"; shift; fi

# Move to the macOS Trash instead of deleting, so mistakes can be undone from Finder.
trash() { mv "$1" "$HOME/.Trash/$(basename "$1" .txt)-$(date +%s).txt" && echo "moved $(basename "$1") to Trash"; }

case "$1" in
  "")
    command -v fzf >/dev/null || { echo "Needs fzf (brew install fzf), or use: $0 all" >&2; exit 1; }
    (cd "$DIR" && for f in *.txt; do echo "${f%.txt}"; done) | fzf \
      --preview "cat '$DIR/{}.txt'" --preview-window 'right,75%,border-left' \
      --header 'enter: run fastfetch · ctrl-d: move to Trash · esc: quit' \
      --bind "ctrl-d:execute-silent(mv '$DIR/{}.txt' \"\$HOME/.Trash/{}-\$(date +%s).txt\")+reload(cd '$DIR' && for f in *.txt; do echo \"\${f%.txt}\"; done)" \
      | while read -r name; do fastfetch --logo "$DIR/$name.txt" --logo-type file-raw; done
    ;;
  all)
    files=("$DIR"/*.txt); n=${#files[@]}; i=0
    for f in "${files[@]}"; do
      i=$((i + 1)); clear
      printf '[%d/%d] %s\n\n' "$i" "$n" "$(basename "$f" .txt)"
      cat "$f"
      printf '\n\nenter: next · d: move to Trash · q: quit '; read -r key
      case "$key" in
        q) break ;;
        d) trash "$f"; sleep 0.7 ;;
      esac
    done
    ;;
  ff) fastfetch --logo "$DIR/$2.txt" --logo-type file-raw ;;
  *)  cat "$DIR/$1.txt" ;;
esac
