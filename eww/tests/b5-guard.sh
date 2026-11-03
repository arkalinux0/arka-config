#!/usr/bin/env bash
# B5: limite di memoria (istanza isolata). Limite 40 MB = sotto qualunque daemon:
#  - il primo daemon viene sostituito (riavvio pulito)
#  - il nuovo NON viene riavviato di nuovo entro la pausa (niente riavvii a ripetizione)
export RCFG=/tmp/eww-real-iso-b5 RRUN=/tmp/eww-real-iso-b5-run
source "$(dirname "$0")/iso-real.sh"
export EWW_MEM_LIMIT_MB=40 EWW_MEM_EVERY=3 EWW_MEM_COOLDOWN=600 EWW_MEM_STAMP=/tmp/eww-real-iso-b5.stamp
rm -f $EWW_MEM_STAMP
real_setup; p0=$(real_pids | head -1); res=0
for i in $(seq 1 60); do kill -0 $p0 2>/dev/null || break; sleep 0.5; done
sleep 4; p1=$(real_pids | head -1)
echo "  1° daemon sostituito: $(kill -0 $p0 2>/dev/null && echo no || echo sì) (nuovo $p1, $(awk '/VmRSS/{print int($2/1024)}' /proc/$p1/status 2>/dev/null) MB)"
kill -0 $p0 2>/dev/null && res=1
sleep 25; p2=$(real_pids | head -1)
echo "  dopo altri 25 s: stesso daemon = $( [ "$p2" = "$p1" ] && echo sì || echo "no ($p2)") , daemon=$(real_daemons), barra=$(real_eww active-windows 2>/dev/null | grep -c '^bar-0:')"
[ "$p2" = "$p1" ] && [ "$(real_daemons)" = 1 ] || res=1
real_cleanup; rm -f $EWW_MEM_STAMP; exit $res
