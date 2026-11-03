#!/usr/bin/env bash
# Esegue TUTTA la suite di test e stampa un riepilogo.
#   bash ~/.config/eww/tests/run-all.sh            (tutto, ~15 min)
#   QUICK=1 bash ~/.config/eww/tests/run-all.sh    (senza i test lunghi)
# Azioni pericolose: solo comandi finti. Test pesanti/concorrenti: solo su
# istanza isolata (iso-real.sh / iso-lib.sh). Log completo in last-run.log.
D="$(cd "$(dirname "$0")" && pwd)"
LOG="$D/last-run.log"; : > "$LOG"
declare -a NAMES RESULTS
run() {  # run <nome> <timeout s> <comando...>
  local name=$1 to=$2; shift 2
  local t0=$(date +%s)
  echo "===== $name (inizio $(date +%T))" >>"$LOG"
  timeout "$to" "$@" >>"$LOG" 2>&1; local rc=$?
  local dt=$(( $(date +%s)-t0 ))
  local res; case $rc in 0) res=PASS ;; 124) res="TIMEOUT" ;; *) res="FAIL(rc=$rc)" ;; esac
  NAMES+=("$name"); RESULTS+=("$res ${dt}s")
  printf "  %s %-28s %s\n" "$(date -d @$t0 +%T)" "$name" "$res (${dt}s)"
}
echo "Suite eww — $(date '+%F %T')"
run "statici"              60  bash "$D/t-static.sh"
run "unitari python"      120  python3 -I "$D/t-unit.py"
run "eventi hyprland"      90  python3 -I "$D/t-events.py"
run "avvisi batteria"      30  python3 -I "$D/t-battery.py"
run "script (stub)"       240  bash "$D/t-stubs.sh"
run "power.sh (stub)"     120  bash "$D/power-test.sh"
run "condizioni ostili"   240  bash "$D/t-hostile.sh"
run "dal vivo (leggeri)"  120  bash "$D/t-live.sh"
run "osd"                  90  bash "$D/osd-test.sh"
run "musica"              120  bash "$D/media-regr.sh"
run "musica: ritardi B4"  240  bash "$D/b4-media.sh"
run "popup iso"           500  bash "$D/t-popup-iso.sh"
run "B1 daemon occupato"  150  bash "$D/b1-busy.sh"
run "B1 duplicato"        150  bash "$D/b1-dup.sh"
if [ -z "$QUICK" ]; then
run "B1 daemon bloccato"  200  bash "$D/b1-recover.sh"
run "B2 aperture pesanti" 300  env MODE=new N=10 bash "$D/b2-test.sh"
run "B5 limite memoria"   200  bash "$D/b5-guard.sh"
fi
run "musica: titoli ostili" 120 bash "$D/t-media-hostile.sh"
run "N3 daemon occupato"  150  bash "$D/n3-test.sh"
run "N4 watchdog vs lock" 150  bash "$D/n4-test.sh"
run "recover.sh"          200  bash "$D/t-recover.sh"
run "N5 ripristini ripetuti" 150 bash "$D/n5-test.sh"
run "multi-monitor"       150  bash "$D/t-multimon.sh"
run "consumi"             120  bash "$D/t-perf.sh"
run "stato finale"         30  bash "$D/state-check.sh"
fails=0; for r in "${RESULTS[@]}"; do [[ "$r" == PASS* ]] || fails=$((fails+1)); done
echo "PASS totali nel log: $(grep -c '^\s*PASS' "$LOG")   FAIL nel log: $(grep -c '^\s*FAIL' "$LOG")"
echo "Gruppi falliti: $fails / ${#RESULTS[@]}"
[ $fails = 0 ]
