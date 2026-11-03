#!/usr/bin/env bash
# Libreria comune per gli script che comandano eww. Da usare con:
#   source "$(dirname "$0")/lib.sh"
#
# Perché esiste (TEST_REPORT B1/B2): se il daemon è occupato (reload, apertura
# di una finestra pesante, nuovo monitor) un "eww open" può andare in timeout,
# e eww 0.5 in quel caso AVVIA UN SECONDO DAEMON. Il primo resta vivo con le
# sue finestre (es. il "closer" a tutto schermo) e blocca click e scroll.
#   - eww_      : ogni comando con --no-daemonize -> il client non avvia mai
#                 un daemon nuovo (al massimo fallisce)
#   - eww_lock  : un solo script alla volta apre/chiude finestre (niente
#                 aperture concorrenti, che mettono in crisi eww)
#   - eww_alive : il daemon risponde?
#   - eww_open_verified : apre e controlla che la finestra ci sia davvero
#                 (con --no-daemonize un open fallito può tornare rc=0)

EWW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EWW_RUN="${XDG_RUNTIME_DIR:-/tmp}"
EWW_LOCK_FILE="$EWW_RUN/eww-ops.lock"

eww_() { timeout "${EWW_TIMEOUT:-10}" eww --no-daemonize -c "$EWW_DIR" "$@"; }

# eww_q: come eww_, ma se il daemon è occupato (rc!=0: il client si arrende)
# ritenta fino a 5 volte. Serve per letture e update: un "update" mandato al
# daemon occupato va PERSO, e una lettura fallita torna vuota (FIX_LOG N3).
eww_q() {
  local i out
  for i in 1 2 3 4 5; do
    if out="$(eww_ "$@" 2>/dev/null)"; then printf '%s' "$out"; [ -n "$out" ] && echo; return 0; fi
    sleep 0.2
  done
  return 1
}

# registro delle azioni correttive (chi ha chiuso cosa e perché)
eww_log() { mkdir -p "$HOME/.cache/eww"; echo "$(date '+%F %T.%3N') [$(basename "$0") $EWW_DIR] $*" >>"$HOME/.cache/eww/actions.log"; }

eww_alive() { eww_q ping >/dev/null; }

# eww_lock [secondi]: prende il lock globale delle finestre su fd 9
eww_lock() {
  exec 9>"$EWW_LOCK_FILE"
  flock -w "${1:-3}" 9
}

eww_unlock() { flock -u 9 2>/dev/null; exec 9>&- 2>/dev/null; }

# id finestre aperte, una per riga. rc!=0 se il daemon non risponde: in quel
# caso il chiamante NON deve trattare il risultato come "nessuna finestra".
# Attenzione: con il daemon occupato eww può perdere la risposta e uscire con
# rc=0 e output VUOTO; c'è sempre almeno la barra, quindi vuoto = fallito.
eww_windows() {
  local w i
  for i in 1 2 3 4 5; do
    w="$(eww_q active-windows)" && [ -n "$w" ] && { cut -d: -f1 <<<"$w" | grep -v '^$'; return 0; }
    sleep 0.2
  done
  return 1
}

eww_is_open() { local w; w="$(eww_windows)" || return 1; grep -qx "$1" <<<"$w"; }

# eww_open_verified <id> <argomenti di eww open...>
eww_open_verified() {
  local id="$1"; shift
  eww_ open "$@" >/dev/null 2>&1
  # il client eww si arrende dopo ~135 ms, ma il daemon finisce comunque di
  # costruire la finestra (il dashboard ci mette ~300 ms): si aspetta fino a 3 s
  local i
  for i in $(seq 1 30); do
    eww_is_open "$id" && return 0
    sleep 0.1
  done
  return 1
}
