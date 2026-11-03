#!/usr/bin/env bash
# Test B1 deterministico: il daemon è "occupato" (sospeso con SIGSTOP per 3 s)
# mentre arrivano i click sul dashboard. Il bug: un client avvia un secondo daemon.
source "$(dirname "$0")/iso-real.sh"
real_setup
d0=$(real_pids | head -1)
echo "  avvio: daemon=$(real_daemons) (pid $d0)"
kill -STOP $d0
for i in 1 2 3; do ( real_run timeout 25 "$RCFG/scripts/popup.sh" dashboard >/dev/null 2>&1 ) & sleep 0.3; done
sleep 3; kill -CONT $d0; wait; sleep 3
d=$(real_daemons); echo "  click con daemon occupato: daemon in ascolto = $d"
# il closer del daemon originale è rimasto aperto senza popup?
echo "  finestre del daemon che risponde: $(real_eww active-windows | cut -d: -f1 | tr '\n' ' ')"
real_cleanup
[ "$d" = 1 ]
