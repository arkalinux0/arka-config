#!/usr/bin/env python3
"""
Barre cava per eww (deflisten). cava gira SOLO mentre un player è in
riproduzione: quando si mette in pausa/ferma il processo viene chiuso.
Output: {"big": [24 valori 0-100], "small": [12 valori]}
"""
import json
import os
import subprocess
import threading
import time

def _die_with_parent():
    """Il processo figlio riceve SIGTERM se questo script muore (niente orfani)."""
    import ctypes, signal
    ctypes.CDLL("libc.so.6", use_errno=True).prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG


CONFIG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "cava", "config")
BIG = 24
ZERO = json.dumps({"big": [0] * BIG, "small": [0] * (BIG // 2)})

playing = threading.Event()
cava = None
cava_lock = threading.Lock()


def watch_status():
    while True:
        try:
            proc = subprocess.Popen(preexec_fn=_die_with_parent, args=
                ["playerctl", "--follow", "status"],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
            )
            for line in proc.stdout:
                if line.strip() == "Playing":
                    playing.set()
                else:
                    playing.clear()
                    stop_cava()
            proc.wait()
        except FileNotFoundError:
            return
        playing.clear()
        stop_cava()
        time.sleep(2)


def check_status():
    """Stato attuale del player (query diretta): avvia/ferma cava."""
    try:
        st = subprocess.run(["playerctl", "status"], capture_output=True,
                            text=True, timeout=3).stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired):
        st = ""
    if st == "Playing":
        playing.set()
    else:
        playing.clear()
        stop_cava()


def resync():
    while True:
        time.sleep(10)
        check_status()


def stop_cava():
    global cava
    with cava_lock:
        if cava and cava.poll() is None:
            cava.terminate()
        cava = None


def main():
    global cava
    # eventi D-Bus MPRIS (TEST_REPORT B4); se Gio non c'è: playerctl --follow
    import mpris_watch
    check_status()
    if not mpris_watch.watch(check_status):
        threading.Thread(target=watch_status, daemon=True).start()
    threading.Thread(target=resync, daemon=True).start()
    print(ZERO, flush=True)
    while True:
        playing.wait()
        with cava_lock:
            cava = subprocess.Popen(preexec_fn=_die_with_parent, args=
                ["cava", "-p", CONFIG], stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL, text=True,
            )
            proc = cava
        for line in proc.stdout:
            try:
                vals = [int(v) for v in line.strip().rstrip(";").split(";")]
            except ValueError:
                continue
            if len(vals) != BIG:
                continue
            small = [max(vals[i], vals[i + 1]) for i in range(0, BIG, 2)]
            print(json.dumps({"big": vals, "small": small}), flush=True)
        proc.wait()
        print(ZERO, flush=True)
        if playing.is_set():
            time.sleep(1)  # cava crashato: riprova senza loop stretto


if __name__ == "__main__":
    main()
