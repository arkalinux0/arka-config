#!/usr/bin/env bash
# Avvio delle app preferite dal dashboard (staccate da eww con setsid).
DIR="$(cd "$(dirname "$0")/.." && pwd)"
"$DIR/scripts/popup.sh" close &
case "$1" in
  network)   setsid -f nm-connection-editor ;;
  bluetooth) setsid -f blueman-manager ;;
  proton)    setsid -f protonvpn-app ;;
  copyq)     setsid -f copyq show ;;
  wireshark) setsid -f wireshark ;;
  waypaper)  setsid -f waypaper ;;
  *) exit 1 ;;
esac >/dev/null 2>&1
