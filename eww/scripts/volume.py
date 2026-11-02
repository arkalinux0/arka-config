#!/usr/bin/env python3
"""
Volume del sink audio di default per eww.

La config originale faceva girare `wpctl get-volume` ogni 10ms (100
volte al secondo, sempre, anche col volume fermo). Qui invece si
riquerya il volume solo quando pipewire segnala un cambiamento tramite
`pactl subscribe`. Va usato con (deflisten ...).
"""
import json
import re
import subprocess
import sys


def get_volume():
    try:
        out = subprocess.check_output(
            ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], text=True
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None

    # Esempio di output: "Volume: 0.45" oppure "Volume: 0.45 [MUTED]"
    m = re.match(r"Volume:\s*([\d.]+)\s*(\[MUTED\])?", out)
    if not m:
        return None

    volume = int(round(float(m.group(1)) * 100))
    muted = bool(m.group(2))
    return {"volume": volume, "muted": muted}


def emit():
    state = get_volume()
    if state is not None:
        print(json.dumps(state), flush=True)


def main():
    emit()

    try:
        proc = subprocess.Popen(
            ["pactl", "subscribe"], stdout=subprocess.PIPE, text=True, bufsize=1
        )
    except FileNotFoundError:
        print("pactl non trovato: impossibile ascoltare i cambi di volume", file=sys.stderr)
        return

    for line in proc.stdout:
        if "sink" in line:
            emit()


if __name__ == "__main__":
    main()
