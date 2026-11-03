#!/usr/bin/env python3
"""
Stato del media player (deflisten). Sostituisce i 3 processi che prima
interrogavano playerctl in parallelo.

Usa i segnali D-Bus MPRIS (mpris_watch.py) e, solo mentre si sta
riproducendo, emette anche il testo scorrevole per la barra.
Output: {"status": "Playing", "artist": "...", "title": "...", "scroll": "..."}
"""
import json
import subprocess
import threading
import time

def _die_with_parent():
    """Il processo figlio riceve SIGTERM se questo script muore (niente orfani)."""
    import ctypes, signal
    ctypes.CDLL("libc.so.6", use_errno=True).prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG


CHARS = 22
FRAME = 0.3
SEP = "   •   "

state = {"status": "Stopped", "artist": "", "title": ""}
lock = threading.Lock()
changed = threading.Event()


# Separatore \x1f (ASCII "unit separator"): non compare nei titoli, a differenza
# della tabulazione usata prima (FIX_LOG N2: un artista con un TAB faceva
# sparire la musica dalla barra).
SEP_FIELD = "\x1f"
FMT = "{{status}}" + SEP_FIELD + "{{artist}}" + SEP_FIELD + "{{title}}"


def clean(text):
    """Tabulazioni e a capo diventano spazi: la barra mostra sempre una riga."""
    return " ".join(text.split())
RESYNC = 10  # secondi: rilettura periodica di sicurezza


def refresh():
    """Legge lo stato completo con una query diretta (fonte di verità)."""
    try:
        out = subprocess.run(["playerctl", "metadata", "--format", FMT],
                             capture_output=True, text=True, timeout=3).stdout
    except (FileNotFoundError, subprocess.TimeoutExpired):
        out = ""
    parts = out.rstrip("\n").split(SEP_FIELD)
    with lock:
        before = dict(state)
        if len(parts) >= 3 and parts[0].strip():
            # se mai l'artista contenesse il separatore, il titolo è l'ultimo campo
            state.update(status=parts[0].strip(), artist=clean(SEP_FIELD.join(parts[1:-1])),
                         title=clean(parts[-1]))
        else:  # nessun player
            state.update(status="Stopped", artist="", title="")
        if state != before:
            changed.set()


def follow():
    # Ogni riga di --follow è solo un "qualcosa è cambiato": lo stato vero
    # si rilegge con refresh(), così eventi parziali o persi non contano.
    while True:
        try:
            proc = subprocess.Popen(preexec_fn=_die_with_parent, args=
                ["playerctl", "--follow", "metadata", "--format", FMT],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
            )
            for _ in proc.stdout:
                refresh()
            proc.wait()
        except FileNotFoundError:
            return
        time.sleep(2)


def resync():
    while True:
        time.sleep(RESYNC)
        refresh()


def label(s):
    if s["artist"] and s["title"]:
        return f"{s['artist']} - {s['title']}"
    return s["title"] or s["artist"]


def main():
    refresh()
    # eventi D-Bus MPRIS (immediati); se Gio non c'è: playerctl --follow
    import mpris_watch
    if not mpris_watch.watch(refresh):
        threading.Thread(target=follow, daemon=True).start()
    threading.Thread(target=resync, daemon=True).start()
    last_out = None
    text, i = "", 0
    while True:
        with lock:
            s = dict(state)
        full = label(s)
        if len(full) <= CHARS:
            scroll = full
        else:
            loop = full + SEP
            if loop != text:
                text, i = loop, 0
            scroll = (loop * 2)[i:i + CHARS]
            if s["status"] == "Playing":
                i = (i + 1) % len(loop)
        out = json.dumps({**s, "scroll": scroll})
        if out != last_out:
            last_out = out
            print(out, flush=True)
        if s["status"] == "Playing" and len(full) > CHARS:
            changed.wait(FRAME)
        else:
            changed.wait()  # fermo: nessun lavoro finché non cambia qualcosa
        changed.clear()


if __name__ == "__main__":
    main()
