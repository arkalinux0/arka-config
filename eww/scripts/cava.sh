#!/usr/bin/env bash

# Use sed to remove the trailing comma at the end of each line before adding brackets
cava -p ~/.config/cava/config_eww | sed -u 's/,$//; s/^/[/; s/$/]/'
