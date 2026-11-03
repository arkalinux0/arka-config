#!/usr/bin/env bash
# bt-connect.sh <MAC>: connette o disconnette un dispositivo accoppiato.
source "$(dirname "$0")/lib.sh"   # eww_ con --no-daemonize e timeout
DIR="$EWW_DIR"
mac="$1"
[[ "$mac" =~ ^([0-9A-F]{2}:){5}[0-9A-F]{2}$ ]] || exit 1
name="$(timeout 2 bluetoothctl info "$mac" | sed -n 's/^\s*Name: //p')"

if timeout 2 bluetoothctl info "$mac" | grep -q "Connected: yes"; then
  timeout 10 bluetoothctl disconnect "$mac" >/dev/null && notify-send -a Bluetooth -i bluetooth "Disconnesso: $name"
else
  eww_q update bt-busy="$mac"
  if timeout 15 bluetoothctl connect "$mac" >/dev/null; then
    notify-send -a Bluetooth -i bluetooth "Connesso: $name"
  else
    notify-send -a Bluetooth -i bluetooth "Connessione fallita: $name"
  fi
  eww_q update bt-busy=""
fi
eww_q update bt="$(bash "$DIR/scripts/bluetooth.sh")" bt-list="$(bash "$DIR/scripts/bt-list.sh")"
