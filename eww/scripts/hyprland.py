#!/usr/bin/env python3
"""
Workspace Hyprland per eww (deflisten).

Ascolta il socket IPC (socket2) e a ogni evento rilevante stampa:
  {"active": 2, "workspaces": [{"id": 1, "windows": 3, "dots": "•••",
                                "mon": 0, "shown": true}, ...]}
  - mon:   indice del monitor (0, 1, ...) nello stesso ordine usato da eww
  - shown: la workspace è quella visibile sul suo monitor
  - active: la workspace con il focus (globale)
Le special (id negativo) vengono ignorate.
"""
import json
import os
import socket
import subprocess
import time

RELEVANT = (
    b"workspace", b"createworkspace", b"destroyworkspace", b"moveworkspace",
    b"focusedmon", b"openwindow", b"closewindow", b"movewindow",
    b"monitoradded", b"monitorremoved",
)

last = None


def hyprctl(*args):
    return json.loads(subprocess.check_output(["hyprctl", *args, "-j"], text=True))


def emit():
    global last
    try:
        ws = hyprctl("workspaces")
        mons = sorted(hyprctl("monitors"), key=lambda m: m["id"])
        active = hyprctl("activeworkspace")["id"]
    except Exception:
        return
    index = {m["id"]: i for i, m in enumerate(mons)}  # id Hyprland -> indice eww
    shown = {m["activeWorkspace"]["id"] for m in mons}
    items = sorted(
        ({"id": w["id"], "windows": w.get("windows", 0),
          # un puntino per finestra (max 4) sotto il numero della workspace
          "dots": "•" * min(w.get("windows", 0), 4),
          "mon": index.get(w.get("monitorID"), 0),
          "shown": w["id"] in shown} for w in ws if w["id"] > 0),
        key=lambda w: w["id"],
    )
    out = json.dumps({"active": active, "workspaces": items})
    if out != last:  # niente update inutili verso eww
        last = out
        print(out, flush=True)


def socket_path():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not sig:
        return None
    return os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "hypr", sig, ".socket2.sock")


def main():
    emit()
    path = socket_path()
    while True:
        if path is None:
            time.sleep(1)
            emit()
            continue
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.connect(path)
                buf = b""
                while chunk := s.recv(4096):
                    buf += chunk
                    *lines, buf = buf.split(b"\n")
                    if any(l.split(b">>", 1)[0].removesuffix(b"v2") in RELEVANT for l in lines):
                        emit()
        except OSError:
            time.sleep(1)


if __name__ == "__main__":
    main()
