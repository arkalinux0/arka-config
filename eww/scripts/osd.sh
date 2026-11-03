#!/usr/bin/env bash
# OSD volume/luminosità: chiamato dai tasti in keybindings.lua.
#   osd.sh volume | osd.sh brightness
# Mostra la finestra "osd" e la richiude 1.5s dopo l'ULTIMA pressione.
# Apertura/chiusura passano dal lock globale e da --no-daemonize (lib.sh).
source "$(dirname "$0")/lib.sh"
TOKEN="$EWW_RUN/eww-osd.token"

case "$1" in
  volume)
    raw="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)"
    value="$(awk '{printf "%d", $2 * 100 + 0.5}' <<<"$raw")"
    muted=false; grep -q MUTED <<<"$raw" && muted=true
    ;;
  brightness)
    value="$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d %)"
    muted=false
    ;;
  *) exit 1 ;;
esac
[[ "$value" =~ ^[0-9]+$ ]] || exit 1

eww_q update osd-kind="$1" osd-value="$value" osd-muted="$muted" >/dev/null || exit 1

token="$(date +%s%N)"
echo "$token" >"$TOKEN"

# l'OSD si apre solo se non c'è già; il lock evita aperture concorrenti
# quando il tasto è tenuto premuto (tante chiamate al secondo)
if ! eww_is_open osd && eww_lock 1; then
  eww_is_open osd || eww_open_verified osd osd --screen "$("$EWW_DIR/scripts/focused-screen.sh")"
  eww_unlock
fi
eww_q update reveal-osd=true >/dev/null

(
  sleep 1.5
  [ "$(cat "$TOKEN")" = "$token" ] || exit 0
  eww_q update reveal-osd=false
  sleep 0.25
  [ "$(cat "$TOKEN")" = "$token" ] || exit 0
  eww_lock 2 && eww_q close osd
) >/dev/null 2>&1 &
disown
