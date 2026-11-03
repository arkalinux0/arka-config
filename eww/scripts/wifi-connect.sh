#!/usr/bin/env bash
# wifi-connect.sh <ssid in base64>
#   rete attiva     -> disconnetti
#   rete salvata    -> nmcli con up
#   rete aperta     -> connetti
#   protetta nuova  -> terminale che chiede la password (eww 0.5 non ha input nel dashboard)
DIR="$(cd "$(dirname "$0")/.." && pwd)"
ssid="$(base64 -d <<<"$1")" || exit 1
[ -z "$ssid" ] && exit 1

notify() { notify-send -a "Wi-Fi" -i network-wireless "$@"; }

active="$(nmcli -t -f ACTIVE,SSID dev wifi | grep -E '^(yes|sì):' | cut -d: -f2-)"
if [ "$active" = "$ssid" ]; then
  nmcli con down id "$ssid" >/dev/null 2>&1 && notify "Disconnesso da $ssid"
elif nmcli -t -f NAME con show | grep -qxF "$ssid"; then
  notify "Connessione a $ssid…"
  nmcli con up id "$ssid" >/dev/null 2>&1 && notify "Connesso a $ssid" || notify "Connessione a $ssid fallita"
else
  sec="$(nmcli -t -f SSID,SECURITY dev wifi list --rescan no | grep -F "$ssid:" | head -1 | cut -d: -f2)"
  if [ -z "$sec" ] || [ "$sec" = "--" ]; then
    nmcli dev wifi connect "$ssid" >/dev/null 2>&1 && notify "Connesso a $ssid" || notify "Connessione a $ssid fallita"
  else
    "$DIR/scripts/popup.sh" close
    kitty --class eww-wifi --title "Wi-Fi: $ssid" sh -c 'nmcli --ask dev wifi connect "$1" && echo && echo "Connesso." ; sleep 2' _ "$ssid"
  fi
fi
"$DIR/scripts/refresh-net.sh"
