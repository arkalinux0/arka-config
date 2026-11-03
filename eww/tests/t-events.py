import os, sys, socket, threading, time, tempfile, importlib.util
SCR = os.path.expanduser("~/.config/eww/scripts")
CASES = {
  "solo cambi di titolo (atteso 0)":       ([b"activewindowv2>>aaa\n"] * 4 + [b"windowtitlev2>>aaa,x\n"], 0),
  "nuova finestra (atteso 1)":             ([b"activewindowv2>>aaa\n", b"activewindowv2>>bbb\n"], 1),
  "A->B->A (atteso 2)":                    ([b"activewindowv2>>aaa\n", b"activewindowv2>>bbb\n", b"activewindowv2>>aaa\n"], 2),
  "focus vuoto non conta (atteso 0)":      ([b"activewindowv2>>aaa\n", b"activewindowv2>>,\n", b"activewindowv2>>\n"], 0),
  "cambio workspace (atteso 1)":           ([b"workspacev2>>2,2\n"], 1),
  "riga spezzata tra due pacchetti (1)":   ([b"activewindowv2>>aaa\n", b"activewin", b"dowv2>>bbb\n"], 1),
}
fails = 0
for name, (chunks, expected) in CASES.items():
    spec = importlib.util.spec_from_file_location("session", os.path.join(SCR, "session.py"))
    s = importlib.util.module_from_spec(spec); spec.loader.exec_module(s)
    d = tempfile.mkdtemp(dir="/tmp"); os.makedirs(os.path.join(d, "hypr", "T"))
    path = os.path.join(d, "hypr", "T", ".socket2.sock")
    srv = socket.socket(socket.AF_UNIX); srv.bind(path); srv.listen(1)
    os.environ["XDG_RUNTIME_DIR"] = d; os.environ["HYPRLAND_INSTANCE_SIGNATURE"] = "T"
    closes = []
    s.close_popup_if_open = lambda *a: closes.append(1)
    s.sync_bars = lambda: True
    def serve():
        c, _ = srv.accept()
        for ch in chunks: c.sendall(ch); time.sleep(0.15)
        time.sleep(0.5); c.close(); srv.close()
    threading.Thread(target=serve, daemon=True).start()
    threading.Thread(target=s.watch_hyprland, daemon=True).start()
    time.sleep(0.4 + 0.15 * len(chunks) + 0.6)
    print(("PASS " if len(closes) == expected else "FAIL ") + f"{name}: chiusure={len(closes)}")
    fails += len(closes) != expected
sys.exit(1 if fails else 0)
