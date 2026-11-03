#!/usr/bin/env bash
# N5: dopo un ripristino, un SECONDO ripristino deve funzionare ancora
# (il daemon avviato da recover.sh non deve tenere il lock di recover).
export RCFG=/tmp/eww-real-iso-n5 RRUN=/tmp/eww-real-iso-n5-run
source "$(dirname "$0")/iso-real.sh"
real_setup; sleep 2; res=0; R="$RCFG/scripts/recover.sh"
p0=$(real_pids | head -1); real_run "$R"; sleep 2; p1=$(real_pids | head -1)
echo "  1° ripristino: $p0 -> $p1"; [ "$p1" != "$p0" ] || res=1
held=$(ls -l /proc/$p1/fd 2>/dev/null | grep -c eww-recover.lock)
echo "  il nuovo daemon tiene il lock di recover: $( [ $held -gt 0 ] && echo SÌ || echo no)"; [ $held = 0 ] || res=1
real_run "$R"; sleep 2; p2=$(real_pids | head -1)
echo "  2° ripristino: $p1 -> $p2"; [ "$p2" != "$p1" ] && [ "$(real_daemons)" = 1 ] || res=1
real_cleanup; exit $res
