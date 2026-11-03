#!/usr/bin/env bash
# B5: RAM del daemon (istanza isolata con la config vera) su N reload.
source "$(dirname "$0")/iso-real.sh"
N=${N:-30}
real_setup; sleep 6
p=$(real_pids | head -1); rss(){ awk '/VmRSS/ {printf "%d", $2/1024}' /proc/$p/status; }
line="  RAM (MB): avvio=$(rss)"
for i in $(seq 1 $N); do
  real_eww reload >/dev/null 2>&1; sleep 4
  p=$(real_pids | head -1)
  [ $((i % 5)) = 0 ] && line="$line  r$i=$(rss)"
done
echo "$line"
sleep 15; echo "  dopo 15 s di riposo: $(rss) MB (daemon $(real_daemons))"
real_cleanup
