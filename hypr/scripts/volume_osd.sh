#!/bin/bash

VOL_RAW=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
VOL=$(echo "$VOL_RAW" | awk '{print $2 * 100}')
VOL=${VOL%.*}

if echo "$VOL_RAW" | grep -q "MUTED"; then
    hyprctl notify 7 3000 0 "volume: muted"
else
    hyprctl notify 7 3000 0  "Volume: $VOL%"
fi
