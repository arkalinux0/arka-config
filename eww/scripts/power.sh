#!/usr/bin/env bash
# Azioni di sessione con conferma: il primo click "arma" l'azione
# (il pulsante mostra "Conferma?"), il secondo entro 3s la esegue.
# lock non chiede conferma.
source "$(dirname "$0")/lib.sh"   # eww_ con --no-daemonize e timeout
DIR="$EWW_DIR"

action="$1"
# solo le 4 azioni note (TEST_REPORT B9): qualunque altro valore viene ignorato
case "$action" in lock|logout|reboot|poweroff) ;; *) exit 2 ;; esac

run() {
  "$DIR/scripts/popup.sh" close
  case "$action" in
    lock)     hyprlock & disown ;;
    logout)   hyprctl dispatch 'hl.dsp.exit()' ;;
    reboot)   systemctl reboot ;;
    poweroff) systemctl poweroff ;;
  esac
}

if [ "$action" = "lock" ] || [ "$(eww_q get power-confirm)" = "$action" ]; then
  run
  exit 0
fi

eww_q update power-confirm="$action"
(
  sleep 3
  [ "$(eww_q get power-confirm)" = "$action" ] && eww_q update power-confirm=""
) &
