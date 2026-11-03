#!/usr/bin/env bash
# Istanza ISOLATA della config VERA, per i test di concorrenza/stress.
#   source iso-real.sh; real_setup; ...; real_cleanup
# - copia della config in $RCFG (socket/lock/pid separati: XDG_RUNTIME_DIR finto
#   con link ai socket di wayland, hyprland, pipewire, dbus)
# - tutte le finestre su layer "bottom" e senza zona esclusiva: stanno DIETRO
#   le finestre dell'utente, non bloccano nulla
# - niente systray (non deve contendere il watcher alla barra vera)
RCFG=${RCFG:-/tmp/eww-real-iso}
RRUN=${RRUN:-/tmp/eww-real-iso-run}
REAL_RUN=${REAL_RUN:-/run/user/$(id -u)}

real_setup() {
  rm -rf "$RCFG" "$RRUN"; mkdir -p "$RRUN"; chmod 700 "$RRUN"
  cp -a "${RSRC:-$HOME/.config/eww}" "$RCFG"; rm -rf "$RCFG/.git" "$RCFG/tests"
  sed -i 's/:stacking "fg"/:stacking "bottom"/; s/:stacking "overlay"/:stacking "bottom"/; s/:exclusive true/:exclusive false/' "$RCFG/windows.yuck"
  [ "${KEEP_TRAY:-0}" = 1 ] || sed -i 's/(island-tray)//' "$RCFG/windows.yuck"
  local f
  for f in "$REAL_RUN"/*; do
    case "$(basename "$f")" in eww*|*.lock|*.pid|*.token) continue ;; esac
    ln -s "$f" "$RRUN/$(basename "$f")"
  done
  # EWW_NO_EVENT_CLOSE: i popup di prova non si chiudono sugli eventi dell'Hyprland vero
  EWW_NO_EVENT_CLOSE=1 XDG_RUNTIME_DIR="$RRUN" setsid -f eww -c "$RCFG" open bar --id bar-0 --arg monitor=0 >/dev/null 2>&1
  local i; for i in $(seq 1 50); do real_eww active-windows 2>/dev/null | grep -q '^bar-0:' && break; sleep 0.2; done
}

real_eww() { XDG_RUNTIME_DIR="$RRUN" timeout 10 eww --no-daemonize -c "$RCFG" "$@"; }
real_run() { EWW_NO_EVENT_CLOSE=1 XDG_RUNTIME_DIR="$RRUN" "$@"; }

real_pids() {
  local p
  for p in $(pgrep -x eww); do
    tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null | grep -q -- "$RCFG" && echo $p
  done
}
real_daemons() {
  local p n=0
  for p in $(real_pids); do ss -xlp 2>/dev/null | grep -q "pid=$p," && n=$((n+1)); done
  echo $n
}
_tree() { local p; for p in $(pgrep -P "$1"); do echo "$p"; _tree "$p"; done; }
real_cleanup() {
  local p tree=""
  # tutti i discendenti dei daemon di prova (script e loro figli), così
  # non restano processi orfani dopo il test
  for p in $(real_pids); do tree="$tree $(_tree $p)"; done
  for p in $(real_pids); do kill $p 2>/dev/null; done; sleep 0.7
  for p in $tree; do kill $p 2>/dev/null; done
  for p in $(real_pids); do kill -9 $p 2>/dev/null; done
  # script figli della copia (solo quelli che girano dalla copia)
  for p in $(pgrep -f "^python3 -u scripts/|^bash scripts/"); do
    [ "$(readlink /proc/$p/cwd 2>/dev/null)" = "$RCFG" ] && kill $p 2>/dev/null
  done
  rm -rf "$RCFG" "$RRUN"
}
