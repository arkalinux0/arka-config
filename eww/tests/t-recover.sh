#!/usr/bin/env bash
# recover.sh: casi limite, su istanza isolata (path separati dalla suite).
export RCFG=/tmp/eww-real-iso-rec RRUN=/tmp/eww-real-iso-rec-run
source "$(dirname "$0")/iso-real.sh"
res=0
t(){ if eval "$2"; then echo "  PASS $1"; else echo "  FAIL $1 [daemon=$(real_daemons) finestre=$(real_eww active-windows 2>/dev/null | tr '\n' ' ')]"; res=1; fi; }
real_setup; sleep 2
R="$RCFG/scripts/recover.sh"
p0=$(real_pids | head -1)
out=$(real_run "$R" --dry-run); t "--dry-run: elenca il daemon e non tocca nulla" 'grep -q "$p0" <<<"$out" && kill -0 $p0 && [ "$(real_daemons)" = 1 ]'
# due ripristini simultanei: uno solo deve agire (flock), alla fine 1 daemon
real_run setsid -f "$R"; real_run setsid -f "$R"; sleep 8
t "due ripristini simultanei: 1 daemon con la barra" '[ "$(real_daemons)" = 1 ] && real_eww active-windows | grep -q "^bar-0:"'
t "il vecchio daemon è stato sostituito" '! kill -0 $p0 2>/dev/null'
# nessun daemon in esecuzione: recover lo avvia
for p in $(real_pids); do kill $p; done; sleep 1.5
t "(preparazione) nessun daemon" '[ "$(real_daemons)" = 0 ]'
real_run "$R"; sleep 3
t "senza daemon: recover avvia barra e daemon" '[ "$(real_daemons)" = 1 ] && real_eww active-windows | grep -q "^bar-0:"'
# il ripristino NON tocca la barra vera
t "barra vera non toccata" 'timeout 3 eww --no-daemonize -c ~/.config/eww active-windows | grep -q "^bar-0:"'
real_cleanup; exit $res
