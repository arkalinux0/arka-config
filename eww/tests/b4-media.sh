#!/usr/bin/env bash
# B4: ritardo con cui la variabile "media" (della barra indicata da EWWC) segue
# l'avvio e la chiusura di un player (vlc muto). Stampa i ritardi in ms.
EWWC=${EWWC:-"eww --no-daemonize"}
TONE=${TONE:-/tmp/claude-1000/-home-arka--config-eww/2977c019-6b7f-40b4-90c1-fbc09da03f35/scratchpad/tone.wav}
st() { $EWWC get media 2>/dev/null | jq -r .status; }
worst=0
for run in 1 2 3 4; do
  t0=$(date +%s%N); pc=""; ew=""
  hyprctl dispatch "hl.dsp.exec_cmd(\"cvlc --gain=0 --play-and-exit --meta-title='B4 $run' $TONE\")" >/dev/null
  for i in $(seq 1 150); do
    now=$(( ($(date +%s%N)-t0)/1000000 ))
    [ -z "$pc" ] && [ "$(playerctl -p vlc status 2>/dev/null)" = Playing ] && pc=$now
    [ -n "$pc" ] && [ -z "$ew" ] && [ "$(st)" = Playing ] && ew=$now
    [ -n "$ew" ] && break; sleep 0.05
  done
  sleep 1
  t1=$(date +%s%N); kill $(pgrep -x vlc) 2>/dev/null
  for i in $(seq 1 300); do [ "$(st)" = Stopped ] && break; sleep 0.05; done
  stop=$(( ($(date +%s%N)-t1)/1000000 ))
  d=$(( ${ew:-99999} - ${pc:-0} ))
  echo "  prova $run: avvio ritardo eww=${d}ms   chiusura ritardo eww=${stop}ms"
  [ $d -gt $worst ] && worst=$d; [ $stop -gt $worst ] && worst=$stop
  sleep 1.5
done
echo "  PEGGIORE: ${worst}ms"
[ $worst -lt 1500 ]
