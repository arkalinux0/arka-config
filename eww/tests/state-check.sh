#!/usr/bin/env bash
# Controllo di stato di fine ciclo (regola dell'utente)
res=0
d=$(for p in $(pgrep -x eww); do ss -xlp 2>/dev/null | grep -q "pid=$p," && echo $p; done | wc -l)
w=$(timeout 3 eww --no-daemonize active-windows 2>/dev/null | cut -d: -f1 | tr '\n' ' ')
c=$(cat ~/.cache/eww/weather-city 2>/dev/null); wc=$(timeout 3 eww --no-daemonize get weather 2>/dev/null | jq -r .city)
reg=$(gdbus call --session --dest org.kde.StatusNotifierWatcher --object-path /StatusNotifierWatcher --method org.freedesktop.DBus.Properties.Get org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null)
pown=$(busctl --user list --no-legend 2>/dev/null | awk '$1 ~ /StatusNotifierItem-proton/ {print $1}' | head -1)
[ -n "$pown" ] && pown=$(gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus --method org.freedesktop.DBus.GetNameOwner $pown 2>/dev/null | tr -d "()',")
iso=$(pgrep -x eww | while read p; do tr '\0' ' ' < /proc/$p/cmdline | grep -qE "/tmp/eww" && echo $p; done | wc -l)
echo "  daemon eww in ascolto: $d $( [ $d = 1 ] && echo OK || { echo ERRORE; res=1; })"
echo "  finestre aperte: $w $( [ "$w" = "bar-0 " ] && echo OK || { echo ERRORE; res=1; })"
echo "  meteo: file=$c barra=$wc $( [ "$c" = Lugano ] && [ "$wc" = Lugano ] && echo OK || { echo ERRORE; res=1; })"
echo "  istanze di test rimaste: $iso $( [ $iso = 0 ] && echo OK || { echo ERRORE; res=1; })"
[ -n "$pown" ] && echo "  Proton nel systray: $(grep -q "$pown/" <<<"$reg" && echo OK || echo 'NO (si ri-registra entro 30 s)')"
exit $res
