#!/usr/bin/env bash
# {"name": "Arka", "initial": "A"} per l'intestazione del dashboard
u="$(whoami)"
jq -nc --arg n "${u^}" --arg i "${u:0:1}" '{name: $n, initial: ($i | ascii_upcase)}'
