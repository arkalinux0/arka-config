#!/bin/bash

BRIGHT=$(brightnessctl get)
MAX=$(brightnessctl max)

PERC=$(( BRIGHT * 100 / MAX ))

# Arrotonda al multiplo di 5 più vicino
PERC=$(( (PERC + 2) / 5 * 5 ))

notify-send "Luminosità: $PERC%"

