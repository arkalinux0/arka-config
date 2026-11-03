#!/usr/bin/env bash
# Regressione musica: rilevamento, scorrimento, pausa, cava (player vlc muto)
TONE=${TONE:-/tmp/claude-1000/-home-arka--config-eww/2977c019-6b7f-40b4-90c1-fbc09da03f35/scratchpad/tone.wav}
E="eww --no-daemonize"; res=0
t(){ if eval "$2"; then echo "  PASS $1"; else echo "  FAIL $1 [media=$($E get media | head -c 100)]"; res=1; fi; }
ncava(){ ps -eo comm | grep -cx cava; }
t "a riposo nessun cava" '[ $(ncava) = 0 ]'
hyprctl dispatch "hl.dsp.exec_cmd(\"cvlc --gain=0 --play-and-exit --meta-artist='Artista Test' --meta-title='Titolo molto lungo che deve scorrere nella barra' $TONE\")" >/dev/null
for i in $(seq 1 60); do [ "$($E get media | jq -r .status)" = Playing ] && break; sleep 0.1; done
t "Playing rilevato" '[ "$($E get media | jq -r .status)" = Playing ]'
t "artista corretto" '[ "$($E get media | jq -r .artist)" = "Artista Test" ]'
s1=$($E get media | jq -r .scroll); sleep 1; s2=$($E get media | jq -r .scroll)
t "testo scorre" '[ "$s1" != "$s2" ]'
sleep 0.5; t "cava avviato" '[ $(ncava) = 1 ]'
t "barre 24/12" '[ "$($E get cava | jq ".big|length")" = 24 ] && [ "$($E get cava | jq ".small|length")" = 12 ]'
playerctl -p vlc pause; sleep 0.6
t "pausa rilevata entro 0.6s" '[ "$($E get media | jq -r .status)" = Paused ]'
t "cava fermo in pausa" '[ $(ncava) = 0 ]'
p1=$($E get media | jq -r .scroll); sleep 1; t "testo fermo in pausa" '[ "$p1" = "$($E get media | jq -r .scroll)" ]'
playerctl -p vlc play; sleep 0.8; t "ripresa: cava riparte" '[ $(ncava) = 1 ]'
playerctl -p vlc next 2>/dev/null; sleep 0.3
kill $(pgrep -x vlc) 2>/dev/null; sleep 0.8
t "player chiuso: Stopped e vuoto" '[ "$($E get media | jq -r .status)" = Stopped ] && [ -z "$($E get media | jq -r .title)" ]'
t "cava fermo" '[ $(ncava) = 0 ]'
t "nessun playerctl/cava orfano" '[ $(ps -eo comm | grep -cxE "cava") = 0 ]'
exit $res
