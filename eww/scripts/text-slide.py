#!/usr/bin/env python3
"""
Testo scorrevole (artista - titolo) per eww, pensato per girare come
(deflisten ...) persistente.

Prima: `get_text()` veniva chiamato una sola volta all'avvio, e il loop
scorreva per sempre sulla stessa stringa catturata all'inizio. Risultato:
se cambiavi canzone, il testo mostrato in barra restava quello della
canzone con cui era partito eww. Ora si ripolla playerctl periodicamente
e, quando il testo cambia, si rigenera la stringa da scorrere e si
riparte dall'inizio.
"""
import time
import subprocess

CHARS = 20
POLL_EVERY = 0.2          # intervallo di ogni frame di scroll
REFRESH_TRACK_EVERY = 1.0  # ogni quanti secondi ricontrollare playerctl


def get_text():
    try:
        return subprocess.check_output(
            ["playerctl", "metadata", "-f", "{{ artist }} - {{ title }}"], text=True
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""


def build_scroll_text(raw):
    # Prima, se playerctl non restituiva nulla, text era "" e la riga
    # `i = (i + 1) % len(text)` più sotto andava in ZeroDivisionError.
    base = raw or "..."
    return base + " " * 5


def main():
    current_track = None
    text = build_scroll_text("")
    i = 0
    last_check = 0.0

    while True:
        now = time.monotonic()
        if now - last_check >= REFRESH_TRACK_EVERY:
            last_check = now
            raw = get_text()
            if raw != current_track:
                current_track = raw
                text = build_scroll_text(raw)
                i = 0

        substr = text[i:i + CHARS + 1]
        if len(substr) < CHARS:
            substr += text[0:CHARS - len(substr)]

        print(substr, flush=True)
        i = (i + 1) % len(text)
        time.sleep(POLL_EVERY)


if __name__ == "__main__":
    main()
