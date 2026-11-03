#!/usr/bin/env python3
"""
Volume del sink di default (deflisten). Rilegge wpctl solo quando
pipewire segnala un evento sui sink (pactl subscribe).
Se pactl manca (TEST_REPORT B8) non si termina: si rilegge ogni 2 s.
Output: {"volume": 45, "muted": false}
"""
import json
import re
import subprocess
import time

def _die_with_parent():
    """Il processo figlio riceve SIGTERM se questo script muore (niente orfani)."""
    import ctypes, signal
    ctypes.CDLL("libc.so.6", use_errno=True).prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG


last = None


def emit():
    global last
    try:
        out = subprocess.check_output(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"],
                                      text=True, stderr=subprocess.DEVNULL, timeout=3)
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
        return
    m = re.match(r"Volume:\s*([\d.]+)\s*(\[MUTED\])?", out.strip())
    if not m:
        return
    state = json.dumps({"volume": round(float(m.group(1)) * 100), "muted": bool(m.group(2))})
    if state != last:
        last = state
        print(state, flush=True)


def main():
    emit()
    while True:
        try:
            proc = subprocess.Popen(preexec_fn=_die_with_parent, args=["pactl", "subscribe"],
                                    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        except FileNotFoundError:
            # niente pactl: niente eventi, si rilegge a intervalli
            time.sleep(2)
            emit()
            continue
        for line in proc.stdout:
            if "sink" in line or "server" in line:
                emit()
        proc.wait()  # pipewire riavviato: ci si risottoscrive
        time.sleep(1)  # pipewire non pronto (es. all'avvio): niente loop a vuoto
        emit()


if __name__ == "__main__":
    main()
