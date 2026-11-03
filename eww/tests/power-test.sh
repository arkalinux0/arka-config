#!/usr/bin/env bash
# power.sh con comandi FINTI (systemctl/hyprlock/hyprctl dispatch registrano e basta)
T=$(mktemp -d); mkdir -p $T/bin; LOG=$T/log
for c in systemctl hyprlock loginctl; do printf '#!/bin/bash\necho "%s $*" >> %s\n' $c $LOG > $T/bin/$c; done
printf '#!/bin/bash\n[ "$1" = dispatch ] && { echo "hyprctl $*" >> %s; exit 0; }\nexec /usr/bin/hyprctl "$@"\n' $LOG > $T/bin/hyprctl; chmod +x $T/bin/*
E="eww --no-daemonize"; P=~/.config/eww/scripts/power.sh; res=0
run(){ PATH=$T/bin:$PATH "$P" "$@"; }
t(){ if eval "$2"; then echo "  PASS $1"; else echo "  FAIL $1 [log: $(tr '\n' '|' < $LOG)] [confirm=$($E get power-confirm)]"; res=1; fi; }
$E update power-confirm=""
: > $LOG; run reboot; t "reboot 1° click: arma senza eseguire" '! grep -q systemctl $LOG && [ "$($E get power-confirm)" = reboot ]'
sleep 3.6; t "conferma scade dopo 3s" '[ -z "$($E get power-confirm)" ]'
: > $LOG; run reboot; sleep 0.4; run reboot; sleep 0.4; t "reboot doppio click: systemctl reboot" 'grep -qx "systemctl reboot" $LOG'
: > $LOG; run poweroff; run reboot; t "poweroff poi reboot: niente eseguito" '! grep -q systemctl $LOG && [ "$($E get power-confirm)" = reboot ]'
$E update power-confirm=""
: > $LOG; run lock; sleep 0.3; t "lock immediato" 'grep -q "^hyprlock" $LOG'
: > $LOG; run logout; run logout; t "logout doppio: hl.dsp.exit()" 'grep -q "hyprctl dispatch hl.dsp.exit()" $LOG'
: > $LOG; run poweroff; run poweroff; t "poweroff doppio: systemctl poweroff" 'grep -qx "systemctl poweroff" $LOG'
$E update power-confirm=""
for bad in "rm -rf" "" "REBOOT" "reboot;id" "lock " "../reboot"; do
  : > $LOG; run "$bad"; rc=$?; t "azione non valida [$bad]: rifiutata (rc=$rc), conferma vuota" '[ $rc = 2 ] && [ ! -s $LOG ] && [ -z "$($E get power-confirm)" ]'
done
sleep 3.5; t "stato pulito a fine test" '[ -z "$($E get power-confirm)" ]'
rm -rf $T; exit $res
