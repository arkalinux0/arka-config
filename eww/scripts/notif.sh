#!/usr/bin/env bash
# Stato notifiche swaync (deflisten). All'avvio eww parte prima di swaync:
# swaync-client uscirebbe subito e la campanella resterebbe ferma. Qui si
# riprova finché swaync non risponde, e ci si ricollega se viene riavviato.
#
# swaync-client gira in background e si aspetta con "wait": così, se questo
# script viene terminato (TERM/INT/HUP), il trap chiude anche il figlio invece
# di lasciarlo orfano (FIX_LOG N1).
child=""
trap '[ -n "$child" ] && kill "$child" 2>/dev/null; exit 0' TERM INT HUP
while true; do
  swaync-client -swb 2>/dev/null &
  child=$!
  wait "$child"
  child=""
  sleep 2
done
