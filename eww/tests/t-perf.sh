#!/usr/bin/env bash
# Consumi a riposo della barra vera (solo misure) + processi duplicati/orfani.
SECS=${SECS:-60}; res=0
t(){ if eval "$2"; then echo "  PASS $1"; else echo "  FAIL $1 ${3:+[$3]}"; res=1; fi; }
d=$(for p in $(pgrep -x eww); do ss -xlp | grep -q "pid=$p," && echo $p; done)
t "un solo daemon" '[ $(echo "$d" | wc -w) = 1 ]'
# discendenti del daemon (script e figli)
desc(){ local p; for p in $(pgrep -P $1); do echo $p; desc $p; done; }
pids="$d $(desc $d)"
declare -A c0; for p in $pids; do c0[$p]=$(awk '{print $14+$15}' /proc/$p/stat 2>/dev/null); done
sleep $SECS
hz=$(getconf CLK_TCK); tot=0; lines=""
for p in $pids; do e=$(awk '{print $14+$15}' /proc/$p/stat 2>/dev/null) || continue; dd=$((e-${c0[$p]:-$e})); tot=$((tot+dd))
  lines="$lines$(printf '%6.2f%%  %s' "$(echo "scale=3; $dd/$hz/$SECS*100" | bc)" "$(tr '\0' ' ' </proc/$p/cmdline | cut -c1-60)")\n"; done
cpu=$(echo "scale=2; $tot/$hz/$SECS*100" | bc)
printf '%b' "$lines" | sort -rn | head -6 | sed 's/^/    /'
t "CPU a riposo < 5% di un core (${cpu}%)" '[ $(echo "$cpu < 5" | bc) = 1 ]'
rss=$(awk '/VmRSS/{print int($2/1024)}' /proc/$d/status)
t "RAM del daemon sotto il limite di 400 MB (${rss} MB)" '[ $rss -lt 400 ]'
# un solo script per tipo, nessun processo orfano della barra
dup=$(for p in $(desc $d); do tr '\0' ' ' </proc/$p/cmdline; echo; done | grep -E "scripts/" | sort | uniq -d)
t "nessuno script duplicato" '[ -z "$dup" ]' "$dup"
orph=$(ps -eo pid,ppid,args | awk '$2==1 && ($3 ~ /playerctl|pactl|swaync-client|^cava$/ || $0 ~ /eww\/scripts|scripts\/[a-z-]+\.(py|sh)/)' | grep -v grep)
t "nessun processo della barra orfano (ppid=1)" '[ -z "$orph" ]' "$orph"
t "nessun 'playerctl --follow' sempre attivo (MPRIS via D-Bus)" '[ $(ps -eo args | grep -c "^playerctl --follow") = 0 ]'
exit $res
