#!/usr/bin/env bash
# Riavvio della rete con il comando dell'utente, in un terminale kitty:
# serve per vedere l'output di "hostname -i" e per la password di sudo.
DIR="$(cd "$(dirname "$0")/.." && pwd)"
"$DIR/scripts/popup.sh" close &

setsid -f kitty --class eww-netrestart --title "Riavvio rete" bash -c '
CMD="hostname -i ; nmcli device disconnect enp0s13f0u1; sudo systemctl restart NetworkManager; sleep 10; sleep 10; hostname -i"
printf "\e[1m󰑓  Riavvio rete\e[0m\n\$ %s\n\n" "$CMD"
eval "$CMD"
printf "\n\e[2mFatto. Premi un tasto per chiudere.\e[0m"
read -rsn1
' >/dev/null 2>&1

# aggiorna il dashboard a riavvio finito (cache IP pubblico inclusa)
( sleep 25; rm -f "${XDG_RUNTIME_DIR:-/tmp}/eww-public-ip"; "$DIR/scripts/refresh-net.sh" ) >/dev/null 2>&1 &
disown
