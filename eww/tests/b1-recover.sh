#!/usr/bin/env bash
# Test del watchdog dei daemon (session.py -> recover.sh)
source "$(dirname "$0")/iso-real.sh"
res=0
real_setup; sleep 11   # il controllo di salute parte 10 s dopo l'avvio
echo "  [duplicato] prima: daemon=$(real_daemons)"
# crea un duplicato come farebbe il vecchio bug: un secondo daemon sullo stesso socket
XDG_RUNTIME_DIR="$RRUN" setsid -f eww -c "$RCFG" daemon >/dev/null 2>&1; sleep 1.5
echo "  [duplicato] creato: daemon=$(real_daemons)"
t0=$(date +%s); for i in $(seq 1 40); do [ "$(real_daemons)" = 1 ] && real_eww active-windows 2>/dev/null | grep -q '^bar-0:' && break; sleep 0.5; done
d=$(real_daemons); echo "  [duplicato] dopo $(( $(date +%s)-t0 ))s: daemon=$d finestre=$(real_eww active-windows 2>/dev/null | cut -d: -f1 | tr '\n' ' ')"
[ "$d" = 1 ] || res=1
sleep 11
p=$(real_pids | head -1); kill -STOP $p; echo "  [bloccato] daemon $p sospeso"
t0=$(date +%s); for i in $(seq 1 80); do kill -0 $p 2>/dev/null || break; sleep 0.5; done
sleep 4; d=$(real_daemons); np=$(real_pids | head -1)
echo "  [bloccato] dopo $(( $(date +%s)-t0 ))s: vecchio vivo=$(kill -0 $p 2>/dev/null && echo sì || echo no) nuovo pid=$np daemon=$d finestre=$(real_eww active-windows 2>/dev/null | cut -d: -f1 | tr '\n' ' ')"
[ "$d" = 1 ] && [ "$np" != "$p" ] || res=1
kill -CONT $p 2>/dev/null
echo "  log di recover: $(tail -2 $HOME/.cache/eww/recover.log | tr '\n' '|')"
real_cleanup
exit $res
