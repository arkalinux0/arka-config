#!/usr/bin/env bash
# IP pubblico per il dashboard (defpoll, solo a dashboard aperto).
# Cache di 5 minuti, invalidata quando cambiano interfaccia principale o
# stato VPN: così non si contatta ifconfig.me a ogni apertura.
CACHE="${XDG_RUNTIME_DIR:-/tmp}/eww-public-ip"
key="$(ip route get 1.1.1.1 2>/dev/null | grep -o 'dev [^ ]*')"
now="$(date +%s)"
if [ -f "$CACHE" ]; then
  read -r c_time c_key c_ip <"$CACHE"
  if [ "$c_key" = "${key// /_}" ] && [ $((now - c_time)) -lt 300 ] && [ -n "$c_ip" ]; then
    echo "$c_ip"; exit 0
  fi
fi
# IPv4 se possibile (più leggibile), altrimenti IPv6
ip="$(curl -4 -s --max-time 5 https://ifconfig.me || curl -6 -s --max-time 5 https://ifconfig.me)"
if [[ "$ip" =~ ^[0-9a-fA-F.:]+$ ]]; then
  echo "$now ${key// /_} $ip" >"$CACHE"
  echo "$ip"
else
  echo "non disponibile"
fi
