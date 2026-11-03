#!/usr/bin/env bash
# copy.sh <campo> [interfaccia]: copia negli appunti un valore della card Rete.
#   campi globali:        public gateway dns wifi band
#   campi di interfaccia: ipv4 ipv6 mac machw   (es. copy.sh ipv4 wlan0)
#
# Il valore NON passa dalla riga di comando generata da eww (TEST_REPORT B6:
# un apostrofo, per es. in un SSID, rompeva il comando): lo si legge qui dai
# dati di eww. Valori multipli (B7): tutti, uno per riga, senza prefisso /NN.
source "$(dirname "$0")/lib.sh"

field="$1"; iface="$2"
[[ "$field" =~ ^(public|gateway|dns|wifi|band|ipv4|ipv6|mac|machw)$ ]] || exit 2
[[ -z "$iface" || "$iface" =~ ^[A-Za-z0-9_.@:-]+$ ]] || exit 2

net="$(eww_ get net 2>/dev/null)"
case "$field" in
  public)  value="$(eww_ get public-ip 2>/dev/null)"; label="IP pubblico" ;;
  gateway) value="$(jq -r '.gateway' <<<"$net")"; label="Gateway" ;;
  dns)     value="$(jq -r '.dns' <<<"$net")"; label="DNS" ;;
  wifi)    value="$(jq -r '.wifi.ssid' <<<"$net")"; label="Wi-Fi" ;;
  band)    value="$(jq -r '"\(.wifi.band) · canale \(.wifi.channel) · \(.wifi.rate)"' <<<"$net")"; label="Banda" ;;
  ipv4|ipv6|mac|machw)
    key="$field"; [ "$field" = machw ] && key=mac_hw
    value="$(jq -r --arg i "$iface" --arg k "$key" '.ifaces[] | select(.name == $i) | .[$k]' <<<"$net")"
    label="$field $iface" ;;
esac

# "a/24, b/16" -> "a\nb"  (un valore per riga, senza prefisso)
value="$(tr ',' '\n' <<<"$value" | sed 's/^ *//; s/ *$//; s|/[0-9]*$||' | grep -v '^$')"
case "$value" in ""|"—"|"null"|"non disponibile"|"…") exit 0 ;; esac

printf '%s' "$value" | wl-copy
notify-send -a Rete -i edit-copy -t 1500 "Copiato: $label" "$value"
