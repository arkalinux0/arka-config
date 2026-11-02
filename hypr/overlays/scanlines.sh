#!/bin/bash

# Kill any previous instance
pkill -f "swww img --transition-type none --resize tile"

# Launch overlay
swww img ~/.config/hypr/overlays/scanlines.png \
    --transition-type none \
    --resize tile \
    --outputs "$(hyprctl monitors -j | jq -r '.[].name')" \
    --filter nearest \
    --invert-y \
    --alpha 0.18
