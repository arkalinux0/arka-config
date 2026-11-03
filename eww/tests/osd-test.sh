#!/usr/bin/env bash
# OSD: valori = sistema, chiusura automatica, raffiche, concorrenza (solo lettura dei valori)
E="eww --no-daemonize"; O=~/.config/eww/scripts/osd.sh; res=0
t(){ if eval "$2"; then echo "  PASS $1"; else echo "  FAIL $1"; res=1; fi; }
isopen(){ $E active-windows | grep -q '^osd:'; }
sv=$(wpctl get-volume @DEFAULT_AUDIO_SINK@); sb=$(brightnessctl -m | cut -d, -f4 | tr -d %)
$O volume; sleep 0.4
t "volume = sistema ($($E get osd-value))" '[ "$($E get osd-value)" = "$(awk "{printf \"%d\", \$2*100+0.5}" <<<"$sv")" ]'
t "muto = sistema ($($E get osd-muted))" '[ "$($E get osd-muted)" = "$(grep -q MUTED <<<"$sv" && echo true || echo false)" ]'
t "visibile (reveal-osd=true)" '[ "$($E get reveal-osd)" = true ] && isopen'
sleep 2.2; t "si chiude da solo dopo ~1.5 s" '! isopen'
$O brightness; sleep 0.4; t "luminosità = sistema ${sb}%" '[ "$($E get osd-value)" = "$sb" ]'
for i in 1 2 3 4 5 6; do $O volume; sleep 0.4; done; t "raffica: resta aperto" 'isopen'
sleep 2.3; t "raffica: chiuso 1.5 s dopo l'ultima" '! isopen'
for i in $(seq 1 12); do $O volume & done; wait; sleep 0.5; t "12 chiamate simultanee: aperto una volta" 'isopen'
sleep 2.3; t "...e poi chiuso" '! isopen'
t "un solo daemon" '[ $(ps -eo comm | grep -cx eww) = 1 ]'
$O boh; t "argomento non valido rifiutato" '[ $? = 1 ]'
exit $res
