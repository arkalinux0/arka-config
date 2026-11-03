#!/usr/bin/env bash
# Ripristino della barra: chiude TUTTI i daemon eww di questa config e ne
# avvia uno solo, pulito, con la barra. Lanciato (staccato, con setsid) dal
# watchdog di session.py quando trova:
#   - più di un daemon in ascolto per questa config (TEST_REPORT B1), oppure
#   - un daemon che non risponde da troppo tempo (bloccato).
# Si può lanciare anche a mano: ~/.config/eww/scripts/recover.sh
#
#   recover.sh [--dry-run]   (--dry-run: mostra cosa farebbe, senza farlo)
DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUN="${XDG_RUNTIME_DIR:-/tmp}"
LOG="$HOME/.cache/eww/recover.log"
DRY=0; [ "$1" = "--dry-run" ] && DRY=1
mkdir -p "$(dirname "$LOG")"

# un solo ripristino alla volta (più watchdog potrebbero chiederlo insieme)
exec 8>"$RUN/eww-recover.lock"
flock -n 8 || exit 0

log() { echo "$(date '+%F %T') $*" >>"$LOG"; [ $DRY = 1 ] && echo "$*"; }

# config dir di un processo eww, letta dalla sua riga di comando
config_of() {
  local args=() a next=""
  mapfile -d '' args <"/proc/$1/cmdline" 2>/dev/null || return 1
  for a in "${args[@]}"; do
    if [ -n "$next" ]; then echo "$a"; return 0; fi
    case "$a" in -c|--config) next=1 ;; --config=*) echo "${a#--config=}"; return 0 ;; esac
  done
  echo "${XDG_CONFIG_HOME:-$HOME/.config}/eww"
}

# daemon = processo eww di QUESTA config con un socket unix in ascolto
daemons() {
  local p cfg
  for p in $(pgrep -x eww); do
    cfg="$(config_of "$p")" || continue
    [ "$(realpath -m "$cfg")" = "$DIR" ] || continue
    ss -xlp 2>/dev/null | grep -q "pid=$p," && echo "$p"
  done
}

pids="$(daemons | tr '\n' ' ')"
log "ripristino richiesto (${REASON:-manuale}); daemon trovati: ${pids:-nessuno}"
[ $DRY = 1 ] && exit 0

for p in $pids; do kill "$p" 2>/dev/null; done
sleep 1
for p in $pids; do kill -0 "$p" 2>/dev/null && kill -9 "$p" 2>/dev/null; done
sleep 0.3

# avvio pulito (questo è l'UNICO punto, oltre all'autostart, che può avviare
# un daemon). setsid: il daemon non dipende da chi ha chiesto il ripristino.
# 8>&- 9>&-: il daemon NON deve ereditare i descrittori dei lock, altrimenti
# terrebbe preso eww-recover.lock per tutta la sua vita e nessun ripristino
# successivo potrebbe più partire (FIX_LOG N5)
setsid -f eww -c "$DIR" open bar --id bar-0 --arg monitor=0 >/dev/null 2>&1 8>&- 9>&-
for i in $(seq 1 50); do
  timeout 2 eww --no-daemonize -c "$DIR" active-windows 2>/dev/null | grep -q '^bar-0:' && break
  sleep 0.2
done
log "ripristino completato; daemon ora: $(daemons | tr '\n' ' ')"
