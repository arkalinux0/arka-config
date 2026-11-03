#!/usr/bin/env bash
# Dispositivi Bluetooth accoppiati (defpoll, solo con la lista aperta) in JSON.
timeout 3 bluetoothctl devices Paired 2>/dev/null | while read -r _ mac name; do
  info="$(timeout 2 bluetoothctl info "$mac" 2>/dev/null)"
  connected=false; grep -q "Connected: yes" <<<"$info" && connected=true
  battery="$(sed -n 's/.*Battery Percentage:.*(\([0-9]*\)).*/\1/p' <<<"$info")"
  icon="$(sed -n 's/^\s*Icon: //p' <<<"$info")"
  name="$(tr '\t\r' '  ' <<<"$name")"   # una riga (FIX_LOG N2)
  jq -nc --arg mac "$mac" --arg name "$name" --argjson c "$connected" \
        --arg bat "$battery" --arg icon "$icon" \
        '{mac: $mac, name: $name, connected: $c, battery: $bat, icon: $icon}'
done | jq -sc 'sort_by(.connected | not)'
