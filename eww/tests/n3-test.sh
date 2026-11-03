#!/usr/bin/env bash
# N3: con il daemon OCCUPATO (SIGSTOP) letture/update falliscono. Verifica che
#  1) il watchdog non chiuda un dashboard legittimo
#  2) una chiusura chiesta mentre il daemon è occupato vada comunque a buon fine
export RCFG=${RCFG:-/tmp/eww-real-iso-n3} RRUN=${RRUN:-/tmp/eww-real-iso-n3-run}
source "$(dirname "$0")/iso-real.sh"
real_setup; sleep 11; res=0
P="$RCFG/scripts/popup.sh"; d=$(real_pids | head -1)
w(){ real_eww active-windows 2>/dev/null | cut -d: -f1 | grep -v '^bar' | sort | tr '\n' ' '; }
real_run "$P" dashboard >/dev/null 2>&1; sleep 1
kill -STOP $d; sleep 4; kill -CONT $d; sleep 4
st=$(w); rv=$(real_eww get reveal-dashboard)
echo "  1) dopo 4 s di daemon occupato: finestre=$st reveal=$rv"
[ "$st" = "closer dashboard " ] && [ "$rv" = true ] || res=1
kill -STOP $d; ( real_run timeout 30 "$P" close >/dev/null 2>&1 ) & sleep 1; kill -CONT $d; wait; sleep 1
st=$(w); echo "  2) close chiesto con daemon occupato: finestre=[$st] popup=[$(real_eww get popup)]"
[ -z "$st" ] || res=1
real_cleanup; exit $res
