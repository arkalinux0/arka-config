#!/usr/bin/env bash
# weather-set.sh <Città>   (Lugano | Bellinzona | Locarno)
case "$1" in Lugano|Bellinzona|Locarno) ;; *) exit 1 ;; esac
mkdir -p ~/.cache/eww
echo "$1" > ~/.cache/eww/weather-city
pid="$(cat "${XDG_RUNTIME_DIR:-/tmp}/eww-weather.pid" 2>/dev/null)"
# il segnale solo se quel PID è davvero weather.py: un pid file vecchio con il
# PID riassegnato farebbe terminare un processo qualunque (FIX_LOG N7)
[[ "$pid" =~ ^[0-9]+$ ]] && tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -q "scripts/weather.py" \
  && kill -USR1 "$pid" 2>/dev/null
exit 0
