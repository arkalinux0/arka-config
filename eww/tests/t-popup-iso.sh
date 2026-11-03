#!/usr/bin/env bash
# Macchina a stati dei popup, concorrenza, watchdog, reload: SOLO su istanza
# isolata con la config vera (finestre dietro le app, socket/lock separati).
source "$(dirname "$0")/iso-real.sh"
real_setup; sleep 11   # watchdog di salute attivo dopo 10 s
P="$RCFG/scripts/popup.sh"; res=0
E(){ real_eww "$@"; }
w(){ E active-windows | cut -d: -f1 | grep -v '^bar' | sort | tr '\n' ' '; }
pop(){ real_run timeout 30 "$P" "$@" >/dev/null 2>&1; }
t(){ if eval "$2"; then echo "  PASS $1"; else echo "  FAIL $1 [finestre=$(w) popup=$(E get popup) daemon=$(real_daemons)]"; res=1; fi; }
ms(){ echo $(( ($(date +%s%N)-$1)/1000000 )); }
coherent(){ local st p; st=$(w); p=$(E get popup)
  { [ -z "$st" ] && [ -z "$p" ]; } || { [ "$st" = "closer dashboard " ] && [ "$p" = dashboard ] && [ "$(E get reveal-dashboard)" = true ]; } \
  || { [ "$st" = "calendar closer " ] && [ "$p" = calendar ] && [ "$(E get reveal-calendar)" = true ]; }; }

echo "== operazioni singole"
t0=$(date +%s%N); pop dashboard; a=$(ms $t0); t "apre dashboard (${a} ms)" '[ "$(w)" = "closer dashboard " ] && [ "$(E get reveal-dashboard)" = true ]'
t0=$(date +%s%N); pop calendar; a=$(ms $t0); t "passa a calendario (${a} ms)" '[ "$(w)" = "calendar closer " ] && [ "$(E get reveal-dashboard)" = false ]'
pop calendar; t "toggle calendario chiude tutto" '[ -z "$(w)" ] && [ -z "$(E get popup)" ]'
pop close; t "close a popup chiuso: nessun effetto" '[ -z "$(w)" ]'
pop boh; t "argomento non valido: ignorato" '[ -z "$(w)" ]'
pop dashboard; E update power-confirm=reboot expand-wifi=true; pop close
t "chiusura azzera conferma spegnimento e liste" '[ -z "$(E get power-confirm)" ] && [ "$(E get expand-wifi)" = false ]'

echo "== click simultanei (stato coerente, mai 2 daemon)"
for n in 2 3 4; do pop close; for i in $(seq 1 $n); do pop dashboard & done; wait
  exp=$([ $((n%2)) = 1 ] && echo "closer dashboard " || echo ""); t "$n click: parità rispettata" '[ "$(w)" = "$exp" ]'; done
for n in 7 10 15; do pop close; for i in $(seq 1 $n); do pop dashboard & done; wait; sleep 0.5
  t "$n click: stato coerente, 1 daemon" 'coherent && [ "$(real_daemons)" = 1 ]'; done
pop close; for i in 1 2 3 4; do pop dashboard & pop calendar & pop close & done; wait; sleep 0.5
t "click misti dashboard/calendario/close: coerente" 'coherent && [ "$(real_daemons)" = 1 ]'

echo "== watchdog (stati orfani creati apposta)"
pop close
wg(){ for i in $(seq 1 30); do sleep 0.25; E active-windows | grep -q "^$1:" || { echo "$((i*250)) ms"; return; }; done; echo "MAI"; }
E open closer >/dev/null 2>&1; r=$(wg closer); t "closer orfano chiuso ($r)" '[ "$r" != MAI ]'
E update popup=dashboard; E open closer >/dev/null 2>&1; E open dashboard >/dev/null 2>&1; r=$(wg dashboard); t "dashboard invisibile chiuso ($r) + closer" '[ "$r" != MAI ] && ! E active-windows | grep -q "^closer:"'
E update popup=calendar reveal-calendar=false; E open closer >/dev/null 2>&1; E open calendar >/dev/null 2>&1; r=$(wg calendar); t "calendario invisibile chiuso ($r)" '[ "$r" != MAI ]'
E open osd >/dev/null 2>&1; r=$(wg osd); t "osd nascosto chiuso ($r)" '[ "$r" != MAI ]'
pop dashboard; sleep 5; t "dashboard visibile NON toccato (5 s)" '[ "$(w)" = "closer dashboard " ]'; pop close

echo "== reload"
pop calendar; sleep 0.3; E reload >/dev/null 2>&1; sleep 9
t "calendario aperto + reload: resta solo la barra" '[ -z "$(w)" ] && E active-windows | grep -q "^bar-0:"'
( E reload >/dev/null 2>&1 ) & sleep 0.2; for i in 1 2 3; do pop dashboard; sleep 0.3; done; wait; sleep 8
t "click durante un reload: coerente, 1 daemon" 'coherent && [ "$(real_daemons)" = 1 ]'
pop close; sleep 6; pop dashboard; sleep 1; t "dopo il reload il dashboard si apre normalmente" '[ "$(w)" = "closer dashboard " ]'; pop close

echo "== daemon occupato (SIGSTOP 3 s) durante i click"
d0=$(real_pids | head -1); kill -STOP $d0
for i in 1 2 3; do ( pop dashboard ) & sleep 0.3; done; sleep 3; kill -CONT $d0; wait; sleep 3
t "1 solo daemon (prima del fix: 2)" '[ "$(real_daemons)" = 1 ]'
t "stato coerente" 'coherent'
real_cleanup; exit $res
