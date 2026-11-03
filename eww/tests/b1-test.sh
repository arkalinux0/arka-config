#!/usr/bin/env bash
# Test B1: click rapidi / apertura durante reload -> mai più di un daemon.
# Uso: RSRC=<config da testare> bash b1-test.sh
source "$(dirname "$0")/iso-real.sh"
real_setup
echo "  avvio: daemon=$(real_daemons) finestre=$(real_eww active-windows | cut -d: -f1 | tr '\n' ' ')"
P="$RCFG/scripts/popup.sh"
res=0
for n in 7 10; do
  for i in $(seq 1 $n); do ( real_run timeout 30 "$P" dashboard >/dev/null 2>&1 ) & done; wait; sleep 3
  d=$(real_daemons); echo "  $n click simultanei: daemon=$d"; [ "$d" = 1 ] || res=1
done
real_run timeout 30 "$P" close >/dev/null 2>&1
( XDG_RUNTIME_DIR="$RRUN" timeout 20 eww --no-daemonize -c "$RCFG" reload >/dev/null 2>&1 ) &
sleep 0.3; for i in 1 2 3; do real_run timeout 30 "$P" dashboard >/dev/null 2>&1; sleep 0.4; done; wait; sleep 4
d=$(real_daemons); echo "  popup aperti durante un reload: daemon=$d"; [ "$d" = 1 ] || res=1
real_cleanup
exit $res
