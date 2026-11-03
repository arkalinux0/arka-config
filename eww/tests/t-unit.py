import sys, os, json, importlib, importlib.util, io, types, time, tempfile, socket, threading, contextlib
SCR = os.path.expanduser("~/.config/eww/scripts")
sys.path.insert(0, SCR)
R = []
def check(name, cond, info=""):
    R.append((name, bool(cond), info)); print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info and not cond else ""))

def load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(SCR, name + ".py"))
    m = importlib.util.module_from_spec(spec)
    with contextlib.redirect_stdout(io.StringIO()):
        try: spec.loader.exec_module(m)
        except SystemExit: pass
    return m

# ---------- network.py
n = load("network")
check("network.fmt B/KB/MB", n.fmt(500) == "500 B/s" and n.fmt(2048) == "2 KB/s" and n.fmt(3*1024**2) == "3.0 MB/s", (n.fmt(500), n.fmt(2048)))
check("network.kind vpn/wifi/eth/virtual", [n.kind(x, "ether") for x in ("proton0","wg0","wlan0","enp0s13f0u1","virbr0","docker0","ipv6leakintrf0")] == ["vpn","vpn","wifi","ethernet","virtual","virtual","virtual"])
check("network.kind sconosciuto -> link_type", n.kind("xyz0", "ether") == "ether")
check("network.is_random_mac casuale", n.is_random_mac("f2:e2:93:d7:e5:f6") is True)
check("network.is_random_mac fisico", n.is_random_mac("9c:67:d6:e5:5b:5a") is False)
check("network.is_random_mac input sporco", n.is_random_mac("") is False and n.is_random_mac("zz:00") is False)

# ---------- wifi-list.py (split_terse)
src = open(os.path.join(SCR, "wifi-list.py")).read()
ns = {}; exec(src.split("saved = set(")[0], ns)
st = ns["split_terse"]
check("wifi split_terse base", st("*:Casa:70:WPA2") == ["*","Casa","70","WPA2"])
check("wifi split_terse ':' escapato nel SSID", st(r" :Rete\:5G:40:WPA2") == [" ","Rete:5G","40","WPA2"])
check("wifi split_terse backslash escapato", st(r" :A\\B:1:--") == [" ", "A\\B", "1", "--"])

# ---------- activewindow.py
a = load("activewindow")
check("activewindow.fmt_bytes", a.fmt_bytes(512) == "512 B" and a.fmt_bytes(2048) == "2 KB" and a.fmt_bytes(5*1024**2) == "5 MB" and a.fmt_bytes(3*1024**3) == "3.00 GB", [a.fmt_bytes(x) for x in (512,2048,5*1024**2,3*1024**3)])
table = {1:(0,0,0), 10:(1,5,100), 11:(10,3,50), 12:(11,2,25), 20:(1,9,9)}
check("activewindow.tree figli e nipoti", sorted(a.tree(10, table)) == [10,11,12])
check("activewindow.tree pid inesistente", a.tree(999, table) == [])
pt = a.proc_table()
check("activewindow.proc_table legge /proc", os.getpid() in pt and len(pt) > 50, len(pt))

# ---------- weather.py
w = load("weather")
check("weather.wmo codici noti", w.wmo(0, True)[1] == "Sereno" and w.wmo(0, False)[0] != w.wmo(0, True)[0])
check("weather.wmo codice sconosciuto", w.wmo(1234)[1] == "—")
check("weather tutte le icone definite", all(len(v) == 3 for v in w.WMO.values()))
with tempfile.TemporaryDirectory() as d:
    w.CITY_FILE = os.path.join(d, "city")
    check("weather città di default se manca il file", w.current_city() == "Lugano")
    open(w.CITY_FILE, "w").write("Atlantide")
    check("weather città non valida -> default", w.current_city() == "Lugano")
    open(w.CITY_FILE, "w").write("Locarno\n")
    check("weather città valida", w.current_city() == "Locarno")
try:
    r = w.fetch("Lugano")
    check("weather.fetch reale (Open-Meteo)", r["ok"] and isinstance(r["temp"], int) and len(r["days"]) == 3, r.get("desc"))
except Exception as e:
    check("weather.fetch reale (Open-Meteo)", False, repr(e))
import urllib.request as ur
orig = ur.urlopen
ur.urlopen = lambda *a, **k: (_ for _ in ()).throw(OSError("offline"))
try:
    w.fetch("Lugano"); check("weather.fetch offline solleva eccezione", False)
except OSError:
    check("weather.fetch offline solleva eccezione (gestita nel main)", True)
ur.urlopen = orig

# ---------- session.py
s = load("session")
with tempfile.TemporaryDirectory() as d:
    s.CACHE = d; s.HISTORY = os.path.join(d, "h.json")
    now = time.time()
    s.save_history([(now - 4000, 90), (now - 1800, 80), (now - 60, 70)])
    h = s.load_history()
    check("session storico: scarta campioni > 1h", [v for _, v in h] == [80, 70], h)
    open(s.HISTORY, "w").write("{rotto")
    check("session storico: file corrotto -> vuoto", s.load_history() == [])
    with contextlib.redirect_stdout(io.StringIO()) as buf:
        s.publish_history([(now - 1800, 80), (now, 79)])
    out = json.loads(buf.getvalue().strip().splitlines()[-1])
    check("session publish: span in minuti", out["battery_span"] == "30 min" and out["battery"] == [80, 79], out)
    with contextlib.redirect_stdout(io.StringIO()) as buf:
        s.publish_history([(now - 3600, 80), (now, 79)])
    check("session publish: span 1 ora", json.loads(buf.getvalue().strip().splitlines()[-1])["battery_span"] == "1 ora")
b = s.battery()
check("session.battery legge BAT*", b is not None and 0 <= b[0] <= 100, b)

# find_orphans con eww finto
def fake(state):
    def eww(*args):
        if args[0] == "active-windows": return "".join(f"{k}: {v}\n" for k, v in state["wins"].items())
        if args[0] == "get": return state["vars"].get(args[1], "") + "\n"
        if args[0] == "state":
            v = {"popup": "", "reveal-dashboard": "false", "reveal-calendar": "false", "reveal-osd": "false", **state["vars"]}
            return "".join(f"{k}: {x}\n" for k, x in v.items())
        return ""
    return eww
cases = [
  ("niente aperto",                   {"bar-0":"bar"}, {}, set()),
  ("dashboard aperto e visibile",     {"bar-0":"bar","closer":"closer","dashboard":"dashboard"}, {"popup":"dashboard","reveal-dashboard":"true"}, set()),
  ("closer senza popup",              {"bar-0":"bar","closer":"closer"}, {"popup":""}, {"closer"}),
  ("dashboard invisibile",            {"bar-0":"bar","closer":"closer","dashboard":"dashboard"}, {"popup":"dashboard","reveal-dashboard":"false"}, {"dashboard"}),
  ("dashboard con popup azzerato",    {"bar-0":"bar","closer":"closer","dashboard":"dashboard"}, {"popup":"","reveal-dashboard":"false"}, {"dashboard","closer"}),
  ("calendario con popup=dashboard",  {"bar-0":"bar","closer":"closer","calendar":"calendar"}, {"popup":"dashboard","reveal-calendar":"true"}, {"calendar","closer"}),
  ("osd nascosto",                    {"bar-0":"bar","osd":"osd"}, {"reveal-osd":"false"}, {"osd"}),
  ("osd visibile",                    {"bar-0":"bar","osd":"osd"}, {"reveal-osd":"true"}, set()),
]
cases += [
  ("active-windows vuoto (risposta persa) -> niente", {}, {"popup":""}, set()),
]
for name, wins, vars_, exp in cases:
    s.eww = fake({"wins": wins, "vars": vars_})
    got = s.find_orphans()
    check(f"watchdog: {name}", got == exp, got)

# risposta persa sullo stato (rc=0, output vuoto) con dashboard aperto -> nessun orfano (N3)
s.eww = lambda *a: ("bar-0: bar\ncloser: closer\ndashboard: dashboard\n" if a[0] == "active-windows" else "")
check("watchdog: stato perso con dashboard aperto -> niente", s.find_orphans() == set())

# ---------- session.py: salute dei daemon (B1) e systray (B3)
s2 = load("session")
real = os.path.realpath(os.path.expanduser("~/.config/eww"))
import subprocess as sp
dpid = None
for p in sp.run(["pgrep", "-x", "eww"], capture_output=True, text=True).stdout.split():
    if s2.config_of(p) == real and int(p) in (s2.listening_pids() or set()):
        dpid = int(p)
check("session.config_of riconosce il daemon della barra", dpid is not None, dpid)
check("session.our_daemons = 1 daemon", s2.our_daemons() == [dpid], s2.our_daemons())
check("session.config_of con -c relativo/assoluto", s2.config_of(os.getpid()) is not None)
check("session.my_daemon_pid fuori da eww = None", s2.my_daemon_pid() is None)
check("session.rss_mb del daemon plausibile", 20 < s2.rss_mb(dpid) < 2000, s2.rss_mb(dpid))
check("session.rss_mb pid inesistente = 0", s2.rss_mb(999999999) == 0)
check("session.tray_resync idempotente (niente da registrare)", s2.tray_resync() == [] and s2.tray_resync() == [])
check("session.ping_ok sul daemon vero", s2.ping_ok() is True)
check("session.MEM_LIMIT_MB predefinito 400", s2.MEM_LIMIT_MB == 400 and s2.MEM_EVERY == 60)

# ---------- mpris_watch.py: un player finto compare/sparisce su D-Bus
mw = load("mpris_watch")
calls = []
check("mpris_watch.watch attivo (Gio disponibile)", mw.watch(lambda: calls.append(time.time()), debounce=0.05) is True)
try:
    import gi; gi.require_version("Gio", "2.0"); from gi.repository import Gio
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    n0 = len(calls)
    oid = Gio.bus_own_name_on_connection(bus, "org.mpris.MediaPlayer2.ewwtest", Gio.BusNameOwnerFlags.NONE, None, None)
    from gi.repository import GLib
    ctx = GLib.MainContext.default()
    end = time.time() + 2
    while time.time() < end and len(calls) == n0:
        ctx.iteration(False); time.sleep(0.02)
    check("mpris_watch: player che compare -> callback", len(calls) > n0, len(calls) - n0)
    n1 = len(calls); Gio.bus_unown_name(oid)
    end = time.time() + 2
    while time.time() < end and len(calls) == n1:
        ctx.iteration(False); time.sleep(0.02)
    check("mpris_watch: player che sparisce -> callback", len(calls) > n1, len(calls) - n1)
    n2 = len(calls)
    oid = Gio.bus_own_name_on_connection(bus, "org.example.nonmpris", Gio.BusNameOwnerFlags.NONE, None, None)
    end = time.time() + 0.8
    while time.time() < end: ctx.iteration(False); time.sleep(0.02)
    Gio.bus_unown_name(oid)
    check("mpris_watch: nomi non-MPRIS ignorati", len(calls) == n2, len(calls) - n2)
except Exception as e:
    check("mpris_watch con player finto", False, repr(e))

ok = sum(1 for _, c, _ in R if c); print(f"\nRISULTATO: {ok}/{len(R)} superati")
sys.exit(0 if ok == len(R) else 1)
