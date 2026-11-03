#!/usr/bin/env bash
# Multi-monitor con monitor VIRTUALI (headless) sulla barra vera.
# È il caso che prima creava un secondo daemon (TEST_REPORT B1).
# letture con ritentativi: mentre il daemon costruisce una barra nuova (~1.5-2 s)
# i comandi eww falliscono (rc=1) e tornano vuoti (FIX_LOG N3)
# (e a volte escono con rc=0 e output vuoto: per active-windows vuoto = fallito)
E(){ local i out; for i in 1 2 3 4 5 6 7 8; do out=$(eww --no-daemonize "$@" 2>/dev/null) && { [ "$1" != active-windows ] || [ -n "$out" ]; } && { printf '%s\n' "$out"; return 0; }; sleep 0.3; done; return 1; }
P=~/.config/eww/scripts/popup.sh; res=0
w(){ E active-windows | cut -d: -f1 | sort | tr '\n' ' '; }
nd(){ for p in $(pgrep -x eww); do ss -xlp | grep -q "pid=$p," && echo $p; done | wc -l; }
t(){ if eval "$2"; then echo "  PASS $1"; else echo "  FAIL $1 [finestre=$(w) daemon=$(nd)]"; res=1; fi; }
cleanup(){ for m in EWWT1 EWWT2 EWWT3; do hyprctl output remove $m >/dev/null 2>&1; done; }
trap cleanup EXIT
t0=$(date +%s%N); hyprctl output create headless EWWT1 >/dev/null
for i in $(seq 1 60); do E active-windows | grep -q '^bar-1:' && break; sleep 0.2; done
t "monitor aggiunto -> bar-1 in $(( ($(date +%s%N)-t0)/1000000 )) ms" 'E active-windows | grep -q "^bar-1:"'
hy=$(E get hypr)
t "workspace del monitor 1 assegnata a mon=1" '[ "$(echo "$hy" | jq "[.workspaces[]|select(.mon==1)]|length")" -ge 1 ]'
t "focused-screen coerente con Hyprland" '[ "$(bash ~/.config/eww/scripts/focused-screen.sh)" = "$(hyprctl monitors -j | jq "sort_by(.id)|to_entries[]|select(.value.focused)|.key")" ]'
# il caso del B1: aprire il dashboard SUBITO dopo aver collegato un monitor
hyprctl output create headless EWWT2 >/dev/null; $P dashboard; sleep 4
t "dashboard aperto subito dopo un nuovo monitor: 1 daemon" '[ "$(nd)" = 1 ]'
# il dashboard può chiudersi se Hyprland sposta il focus sulla workspace del monitor
# nuovo (regola "chiudi al cambio di workspace", registrata in actions.log)
coh(){ local w=$(w); { [ "$(E get reveal-dashboard)" = true ] && grep -q "dashboard" <<<"$w"; } || { ! grep -qE "dashboard|closer" <<<"$w" && [ -z "$(E get popup)" ]; }; }
t "...bar-2 aperta, dashboard visibile o chiuso in modo pulito" 'E active-windows | grep -q "^bar-2:" && coh'
hyprctl output create headless EWWT3 >/dev/null; sleep 0.3; hyprctl output remove EWWT3 >/dev/null; sleep 4
t "monitor aggiunto e tolto di colpo: 1 daemon, niente bar-3" '[ "$(nd)" = 1 ] && ! E active-windows | grep -q "^bar-3:"'
hyprctl output remove EWWT2 >/dev/null; sleep 4
t "tolto il terzo: bar-2 chiusa, stato coerente" '! E active-windows | grep -q "^bar-2:" && coh'
$P close
hyprctl output remove EWWT1 >/dev/null; sleep 4
t "tolto anche il secondo: solo bar-0" '[ "$(w)" = "bar-0 " ]'
t "1 solo daemon alla fine" '[ "$(nd)" = 1 ]'
t "solo il monitor reale" '[ "$(hyprctl monitors -j | jq -r ".[].name" | tr "\n" " ")" = "eDP-1 " ]'
exit $res
