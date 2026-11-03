import os, sys, time, importlib.util, io, contextlib, tempfile, threading
SCR = os.path.expanduser("~/.config/eww/scripts")
spec = importlib.util.spec_from_file_location("session", os.path.join(SCR, "session.py"))
s = importlib.util.module_from_spec(spec); spec.loader.exec_module(s)
seq = [(50,"Discharging"),(16,"Discharging"),(15,"Discharging"),(14,"Discharging"),(10,"Discharging"),
       (5,"Discharging"),(4,"Discharging"),(20,"Charging"),(15,"Discharging"),(99,"Charging"),(100,"Charging"),
       (100,"Full"),(100,"Full"),(99,"Discharging"),(100,"Charging")]
i = [0]; sent = []
s.battery = lambda: seq[min(i[0], len(seq)-1)]
s.notify = lambda title, body, urgency="normal", icon="": sent.append((i[0], seq[i[0]], title, urgency))
d = tempfile.mkdtemp(); s.CACHE = d; s.HISTORY = os.path.join(d, "h.json")
real_sleep = time.sleep
def fake_sleep(x):
    i[0] += 1
    if i[0] >= len(seq): raise SystemExit
s.time.sleep = fake_sleep
with contextlib.redirect_stdout(io.StringIO()):
    try: s.battery_loop()
    except SystemExit: pass
s.time.sleep = real_sleep
for n, (cap, st), title, urg in sent: print(f"  passo {n:2}: {cap:3}% {st:<12} -> {title} [{urg}]")
exp = ["Batteria bassa", "Batteria quasi scarica!", "Batteria bassa", "Batteria carica", "Batteria carica"]
got = [t for _, _, t, _ in sent]
print(("PASS" if got == exp else "FAIL") + f" sequenza avvisi: {got}")
sys.exit(0 if got == exp else 1)
