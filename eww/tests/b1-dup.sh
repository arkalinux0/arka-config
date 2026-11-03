#!/usr/bin/env bash
source "$(dirname "$0")/iso-real.sh"
real_setup; sleep 11
p0=$(real_pids | head -1); echo "  daemon originale $p0, finestre: $(real_eww active-windows | cut -d: -f1 | tr '\n' ' ')"
real_run "$RCFG/scripts/popup.sh" dashboard >/dev/null 2>&1   # closer aperto sul daemon originale
rm -f "$RRUN"/eww-server_*                                     # come fa il client eww prima di avviarne un altro
XDG_RUNTIME_DIR="$RRUN" setsid -f eww -c "$RCFG" daemon >/dev/null 2>&1; sleep 1.5
echo "  duplicato creato: daemon in ascolto=$(real_daemons)"
t0=$(date +%s); for i in $(seq 1 60); do d=$(real_daemons); [ "$d" = 1 ] && kill -0 $p0 2>/dev/null || break; sleep 0.5; done
for i in $(seq 1 30); do real_eww active-windows 2>/dev/null | grep -q '^bar-0:' && [ "$(real_daemons)" = 1 ] && break; sleep 0.5; done
d=$(real_daemons)
echo "  dopo $(( $(date +%s)-t0 ))s: daemon=$d originale vivo=$(kill -0 $p0 2>/dev/null && echo sì || echo no) finestre=$(real_eww active-windows 2>/dev/null | cut -d: -f1 | tr '\n' ' ')"
real_cleanup; [ "$d" = 1 ]
