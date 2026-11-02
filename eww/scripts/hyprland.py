#!/usr/bin/env python3
"""
Stato delle workspace Hyprland per eww.

A differenza della versione precedente (defpoll ogni 100ms che lanciava
hyprctl in continuazione), questo script si mette in ascolto sul socket
IPC di Hyprland (socket2) e ricalcola lo stato solo quando succede
qualcosa di rilevante (cambio workspace, creazione/distruzione, ecc).
Va usato con (deflisten ...) invece di (defpoll ...).
"""
import json
import os
import socket
import subprocess
import sys
import time


def get_state():
    workspaces = json.loads(
        subprocess.check_output(["hyprctl", "workspaces", "-j"], text=True)
    )
    active_workspace = json.loads(
        subprocess.check_output(["hyprctl", "activeworkspace", "-j"], text=True)
    )

    obj = {"active": active_workspace["id"]}

    by_id = {w["id"]: w for w in workspaces}
    for i in range(1, 11):
        w = by_id.get(i)
        obj[f"visible_{i}"] = w is not None
        # In precedenza era sempre hard-coded a 0 se la workspace esisteva:
        # qui usiamo il monitorID reale restituito da hyprctl.
        obj[f"monitor_{i}"] = w["monitorID"] if w is not None else -1

    return obj


def emit():
    try:
        print(json.dumps(get_state()), flush=True)
    except Exception:
        # Se Hyprland non risponde in un dato istante, meglio saltare
        # l'update che far crashare il listener.
        pass


def socket_path():
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not sig:
        return None
    return os.path.join(runtime_dir, "hypr", sig, ".socket2.sock")


RELEVANT_PREFIXES = (
    b"workspace>>",
    b"workspacev2>>",
    b"createworkspace>>",
    b"createworkspacev2>>",
    b"destroyworkspace>>",
    b"destroyworkspacev2>>",
    b"moveworkspace>>",
    b"moveworkspacev2>>",
    b"focusedmon>>",
    b"focusedmonv2>>",
)


def listen_loop(path):
    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.connect(path)
                buf = b""
                while True:
                    chunk = s.recv(4096)
                    if not chunk:
                        break
                    buf += chunk
                    while b"\n" in buf:
                        line, buf = buf.split(b"\n", 1)
                        if line.startswith(RELEVANT_PREFIXES):
                            emit()
        except (OSError, ConnectionError):
            time.sleep(1)


def main():
    emit()

    path = socket_path()
    if path is None:
        # HYPRLAND_INSTANCE_SIGNATURE non impostata (es. script lanciato
        # fuori da una sessione Hyprland): fallback a un refresh ogni secondo
        # invece di restare mute.
        while True:
            time.sleep(1)
            emit()
    else:
        listen_loop(path)


if __name__ == "__main__":
    main()
