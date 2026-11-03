#!/usr/bin/env bash
# Indice (ordine eww) del monitor con il focus.
hyprctl monitors -j 2>/dev/null | jq -r 'sort_by(.id) | to_entries[] | select(.value.focused) | .key' | head -1 | grep . || echo 0
