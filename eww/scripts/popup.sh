#!/usr/bin/env bash
# Gestione popup: ne resta aperto uno solo alla volta, e la finestra
# trasparente "closer" sotto di esso lo chiude al click fuori.
#   popup.sh dashboard   -> apre/chiude il dashboard
#   popup.sh calendar    -> apre/chiude il calendario
#   popup.sh close       -> chiude qualunque popup aperto
#
# - Lo stato si ricava dalle finestre realmente aperte (non da una variabile).
# - Tutte le operazioni sulle finestre passano dal lock globale (lib.sh):
#   niente aperture concorrenti.
# - Nessun comando può avviare un secondo daemon (--no-daemonize), e se il
#   daemon non risponde non si apre niente.
source "$(dirname "$0")/lib.sh"

POPUPS="dashboard calendar"
target="$1"
case "$target" in dashboard|calendar|close) ;; *) exit 2 ;; esac

# Chiudere non deve mai fallire (altrimenti il closer resta su): se il lock
# è occupato la chiusura procede comunque.
if ! eww_lock 3; then
  [ "$target" = "close" ] || exit 1
fi

# daemon non raggiungibile: non aprire nulla (eviterebbe solo un timeout)
eww_alive || exit 1

# se la lettura fallisce (daemon occupato) non si decide nulla su dati vuoti
open_windows="$(eww_windows)" || exit 1
current=""
for p in $POPUPS; do
  grep -qx "$p" <<<"$open_windows" && current="$p"
done

# $1 = "keep" -> lascia aperto il closer (passaggio da un popup all'altro)
close_current() {
  if [ -n "$current" ]; then
    eww_q update "reveal-$current=false" popup="" power-confirm="" \
                 expand-wifi=false expand-bt=false
    sleep 0.22 # lascia finire l'animazione del revealer
    eww_q close "$current" >/dev/null
  fi
  if [ "$1" != "keep" ] && grep -qx closer <<<"$open_windows"; then
    eww_q close closer >/dev/null
  fi
  eww_q update popup="" >/dev/null
}

if [ "$target" = "close" ] || [ "$target" = "$current" ]; then
  close_current
  exit 0
fi

close_current keep

rollback() {
  eww_log "rollback apertura $target (finestra non comparsa o update fallito)"
  eww_q close "$target" closer >/dev/null
  eww_q update popup="" "reveal-$target=false"
  exit 1
}

# Stato PRIMA delle finestre: non c'è mai un momento con il closer aperto e
# "popup" vuoto. Ogni apertura viene verificata; se fallisce si torna indietro
# (niente vetro invisibile sullo schermo).
screen="$("$EWW_DIR/scripts/focused-screen.sh")"
eww_q update popup="$target" || exit 1
if ! grep -qx closer <<<"$open_windows"; then
  eww_open_verified closer closer --screen "$screen" || rollback
fi
eww_open_verified "$target" "$target" --screen "$screen" || rollback
eww_q update "reveal-$target=true" || rollback
