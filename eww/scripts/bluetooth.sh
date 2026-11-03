#!/usr/bin/env bash
# Stato Bluetooth (defpoll): {"powered": true, "devices": ["Cuffie"], "count": 1}
powered=false
if timeout 2 bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
  powered=true
fi

devices="[]"
if [ "$powered" = true ]; then
  devices="$(timeout 2 bluetoothctl devices Connected 2>/dev/null | cut -d' ' -f3- | jq -Rsc 'split("\n") | map(select(length > 0))')"
fi

jq -nc --argjson p "$powered" --argjson d "${devices:-[]}" '{powered: $p, devices: $d, count: ($d | length)}'
