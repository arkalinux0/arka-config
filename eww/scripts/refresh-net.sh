#!/usr/bin/env bash
# Chiede a network.py di rileggere subito lo stato Wi-Fi (SIGUSR1).
# Usa un pidfile: un pkill per nome colpirebbe anche altre istanze.
sleep 0.6
pid="$(cat "${XDG_RUNTIME_DIR:-/tmp}/eww-network.pid" 2>/dev/null)"
# il segnale solo se quel PID è davvero network.py: un pid file vecchio con il
# PID riassegnato farebbe terminare un processo qualunque (FIX_LOG N7)
[[ "$pid" =~ ^[0-9]+$ ]] && tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -q "scripts/network.py" \
  && kill -USR1 "$pid" 2>/dev/null
exit 0
