#!/usr/bin/env bash
# Azioni rapide del dashboard. Stessi percorsi/nomi delle scorciatoie CTRL+Y.
DIR="$(cd "$(dirname "$0")/.." && pwd)"
SHOTS="$HOME/Pictures"
mkdir -p "$SHOTS"

"$DIR/scripts/popup.sh" close
sleep 0.35 # il dashboard deve sparire prima dello screenshot

case "$1" in
  area)
    file="$SHOTS/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"
    geom="$(slurp)" || exit 0 # Esc durante la selezione = annulla
    grim -g "$geom" "$file" ;;
  screen)
    file="$SHOTS/fullscreen-$(date +'%Y-%m-%d_%H-%M-%S').png"
    grim "$file" ;;
  clipboard) exec copyq toggle ;;
  folder)    exec xdg-open "$SHOTS" ;;
  *) exit 1 ;;
esac

if [ -f "$file" ]; then
  wl-copy <"$file"
  notify-send -a Screenshot -i "$file" "Screenshot salvato" "$(basename "$file") — copiato negli appunti"
fi
