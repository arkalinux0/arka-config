#!/usr/bin/env bash
# B2: N aperture simultanee di una finestra pesante (istanza isolata).
# MODE=old  -> come prima (eww open senza protezioni)
# MODE=new  -> come ora gli script: --no-daemonize + lock globale (lib.sh)
source "$(dirname "$0")/iso-lib.sh"
iso_setup 3000
LOCK=/tmp/eww-iso-ops.lock; N=${N:-10}; t0=$(date +%s)
for i in $(seq 1 $N); do
  if [ "$MODE" = new ]; then
    # come eww_open_verified dentro il lock (lib.sh): il lock resta preso finché la finestra non c'è
    ( exec 9>$LOCK; flock -w 120 9 && { timeout 20 eww --no-daemonize -c $ISO open heavy --id h$i >/dev/null 2>&1 </dev/null
        for k in $(seq 1 100); do timeout 5 eww --no-daemonize -c $ISO active-windows 2>/dev/null | grep -q "^h$i:" && break; sleep 0.1; done; } ) &
  else
    ( timeout 20 eww -c $ISO open heavy --id h$i >/dev/null 2>&1 </dev/null ) &
  fi
done
wait
for k in $(seq 1 60); do [ "$(timeout 5 eww --no-daemonize -c $ISO active-windows 2>/dev/null | grep -c '^h')" = "$N" ] && break; sleep 0.5; done
el=$(( $(date +%s)-t0 ))
alive=$(timeout 5 eww --no-daemonize -c $ISO ping 2>/dev/null)
opened=$(timeout 5 eww --no-daemonize -c $ISO active-windows 2>/dev/null | grep -c '^h')
echo "  MODE=$MODE N=$N: tempo=${el}s daemon=$(iso_daemons) risponde=${alive:-NO} finestre aperte=$opened/$N"
d=$(iso_daemons); iso_cleanup
[ "$d" = 1 ] && [ "$alive" = pong ] && [ "$opened" = "$N" ]
