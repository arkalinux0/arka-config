#!/usr/bin/env bash
# N4: il watchdog NON deve chiudere finestre mentre popup.sh tiene il lock
# (apertura in corso). Simula: lock preso per 8 s, closer aperto, popup=dashboard,
# dashboard non ancora aperto (= stato "a metà apertura").
export RCFG=${RCFG:-/tmp/eww-real-iso-n4} RRUN=${RRUN:-/tmp/eww-real-iso-n4-run}
source "$(dirname "$0")/iso-real.sh"
real_setup; sleep 11; res=0
( exec 9>"$RRUN/eww-ops.lock"; flock 9; sleep 8 ) &   # come popup.sh durante un'apertura lenta
sleep 0.3
real_eww update popup=dashboard >/dev/null; real_eww open closer >/dev/null 2>&1
sleep 7
c=$(real_eww active-windows | grep -c '^closer:')
echo "  a 7 s con il lock preso: closer ancora aperto = $c (atteso 1: il watchdog aspetta)"
[ "$c" = 1 ] || res=1
wait; sleep 4
c2=$(real_eww active-windows | grep -c '^closer:')
echo "  lock rilasciato, stato ancora orfano: closer chiuso = $( [ "$c2" = 0 ] && echo sì || echo no) (atteso sì)"
[ "$c2" = 0 ] || res=1
real_cleanup; exit $res
