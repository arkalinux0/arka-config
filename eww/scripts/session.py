#!/usr/bin/env python3
"""
Servizio di sessione della barra (deflisten "session", vive quanto il daemon).

1. Pulizia dopo un reload: eww riapre le finestre che erano aperte ma
   azzera le variabili, quindi un popup resterebbe invisibile e il
   "closer" si mangerebbe il click successivo. Qui si chiudono gli orfani.
   + watchdog: se per 2 controlli di fila (~2s) c'è un popup/closer/OSD
   aperto ma non visibile (stato incoerente per qualunque motivo), lo chiude.
   Il "closer" è una superficie trasparente a tutto schermo: lasciato
   aperto per errore bloccherebbe click e scroll su tutte le finestre.
2. Una barra per monitor: apre "bar-N" per ogni monitor collegato e la
   chiude quando il monitor viene scollegato (eventi Hyprland).
   + i popup si chiudono quando cambi workspace o finestra (es. da tastiera).
3. Batteria: avvisi (15%, 5%, carica completa) e storico dell'ultima ora
   (un campione al minuto, salvato su disco: sopravvive ai riavvii).
5. Systray (TEST_REPORT B3): il watcher del systray è ospitato da eww; dopo
   un riavvio di eww alcune app (es. protonvpn-app) non si ri-registrano e la
   loro icona sparisce. Qui si cercano gli elementi StatusNotifierItem
   presenti su D-Bus ma non registrati e li si registra (metodo standard
   RegisterStatusNotifierItem del protocollo), all'avvio e ogni 30 s.
4. Salute del daemon (TEST_REPORT B1): se ci sono PIÙ daemon eww per questa
   config, o il daemon non risponde da più di 20 s, lancia scripts/recover.sh
   (staccato), che chiude tutti i daemon e ne riavvia uno solo con la barra.
   + limite di memoria (TEST_REPORT B5): il systray di eww 0.5 perde ~6 MB a
   ogni reload (cioè a ogni cambio wallpaper). Oltre MEM_LIMIT_MB, e solo
   senza popup aperti, si fa lo stesso riavvio pulito per liberare la RAM.

Tutti i comandi eww usano --no-daemonize (un client non avvia mai un daemon
nuovo) e le aperture/chiusure di finestre passano dal lock globale
$XDG_RUNTIME_DIR/eww-ops.lock, lo stesso usato da popup.sh e osd.sh.

Output (una riga JSON per aggiornamento):
  {"battery": [82, 81, ...], "battery_span": "58 min"}
"""
import fcntl
import glob
import json
import os
import socket
import subprocess
import threading
import time

DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EWW = ["eww", "--no-daemonize", "-c", DIR]
RUN = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
LOCK_FILE = os.path.join(RUN, "eww-ops.lock")
CACHE = os.path.expanduser("~/.cache/eww")
HISTORY = os.path.join(CACHE, "battery-history.json")
SAMPLE_EVERY = 60    # secondi tra due campioni dello storico
HISTORY_SPAN = 3600  # quanto storico tenere
ALERT_EVERY = 30

out_lock = threading.Lock()
state = {"battery": [], "battery_span": ""}


def emit():
    with out_lock:
        print(json.dumps(state), flush=True)


def eww(*args, tries=5):
    """Comando eww. Ritorna l'output, oppure None se il daemon non ha risposto
    (rc!=0: è occupato o bloccato). Con il daemon occupato le letture tornano
    vuote e gli update vanno persi: si ritenta, e chi chiama NON deve
    interpretare None come "vuoto" (FIX_LOG N3)."""
    for i in range(tries):
        try:
            r = subprocess.run([*EWW, *args], capture_output=True, text=True, timeout=5)
            if r.returncode == 0:
                return r.stdout
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass
        if i < tries - 1:
            time.sleep(0.2)
    return None


def eww_state():
    """Tutte le variabili in UNA lettura (`eww state --all`), come dict.
    None se la lettura è fallita. Con il daemon occupato eww a volte perde la
    risposta ma esce con rc=0 e output VUOTO: per `get popup` un vuoto sarebbe
    indistinguibile da "nessun popup"; lo stato completo invece non è mai vuoto
    (FIX_LOG N3)."""
    raw = eww("state", "--all")
    if not raw or not raw.strip():
        return None
    st = {}
    for line in raw.splitlines():
        if ": " in line:
            k, v = line.split(": ", 1)
            st[k.strip()] = v.strip()
        elif line.endswith(":"):
            st[line[:-1].strip()] = ""
    return st if "popup" in st else None


def eww_get(name):
    """Valore di una variabile, letto dallo stato completo (vedi eww_state)."""
    st = eww_state()
    return None if st is None else st.get(name, "")


class window_lock:
    """Lock globale delle operazioni sulle finestre (come eww_lock in lib.sh).
    `with window_lock() as ok:` -> ok=False se non ottenuto entro `wait` s.
    In quel caso chi chiama NON deve agire: il lock è di popup.sh/osd.sh nel
    mezzo di un'apertura, e chiudere ora romperebbe un'apertura legittima
    (FIX_LOG N4). Si riprova al giro successivo."""
    def __init__(self, wait=3):
        self.wait = wait
        self.f = None

    def __enter__(self):
        self.f = open(LOCK_FILE, "w")
        end = time.monotonic() + self.wait
        while True:
            try:
                fcntl.flock(self.f, fcntl.LOCK_EX | fcntl.LOCK_NB)
                return True
            except OSError:
                if time.monotonic() > end:
                    return False
                time.sleep(0.05)

    def __exit__(self, *exc):
        try:
            fcntl.flock(self.f, fcntl.LOCK_UN)
        finally:
            self.f.close()


def active_windows():
    """id finestra -> nome (es. 'bar-1' -> 'bar'); None se eww non risponde."""
    raw = eww("active-windows")
    # vuoto = risposta persa (c'è sempre almeno la barra quando questo gira)
    if raw is None or not raw.strip():
        return None
    out = {}
    for line in raw.splitlines():
        if ":" in line:
            wid, name = line.split(":", 1)
            out[wid.strip()] = name.strip()
    return out


def log_action(msg):
    """Registro delle azioni correttive in ~/.cache/eww/actions.log."""
    try:
        os.makedirs(CACHE, exist_ok=True)
        with open(os.path.join(CACHE, "actions.log"), "a") as f:
            f.write(time.strftime("%F %T") + f" [session.py {DIR}] {msg}\n")
    except OSError:
        pass


# ---------------------------------------------------------------- 1. reload
def cleanup_orphans():
    # eww riapre le finestre con un ritardo variabile: si controlla più volte.
    # Si chiude solo ciò che è orfano (popup aperto ma variabile azzerata),
    # così un popup aperto dall'utente subito dopo il reload non viene toccato.
    for delay in (1, 1, 2, 3):
        time.sleep(delay)
        with window_lock() as ok:
            if not ok:
                continue
            wins = active_windows()
            popup = eww_get("popup")
            if wins is None or popup is None:
                continue  # eww non risponde: non si decide su dati mancanti
            for w in ("calendar", "dashboard"):
                if w in wins and popup != w:
                    log_action(f"pulizia dopo reload: chiudo {w}")
                    eww("close", w)
            if "closer" in wins and not popup:
                eww("close", "closer")
            if "osd" in wins and eww_get("reveal-osd") == "false":
                eww("close", "osd")


def find_orphans():
    """Finestre popup aperte ma non visibili all'utente.
    Se eww non risponde a una qualunque lettura -> nessun orfano (non si
    chiude nulla sulla base di dati mancanti, FIX_LOG N3)."""
    aw = active_windows()
    if aw is None:
        return set()
    wins = set(aw.values())
    if not wins & {"closer", "dashboard", "calendar", "osd"}:
        return set()  # caso normale: una sola chiamata a eww al secondo
    st = eww_state()  # una sola lettura, coerente, mai vuota se valida
    if st is None:
        return set()
    popup = st.get("popup", "")
    orphans = set()
    for w in ("dashboard", "calendar"):
        if w in wins and (popup != w or st.get(f"reveal-{w}") != "true"):
            orphans.add(w)
    if "closer" in wins and (popup not in ("dashboard", "calendar") or popup not in wins):
        orphans.add("closer")
    if "osd" in wins and st.get("reveal-osd") != "true":
        orphans.add("osd")
    return orphans


def watchdog():
    suspect = set()
    while True:
        time.sleep(1)
        try:
            orphans = find_orphans()
        except Exception:
            continue
        confirmed = orphans & suspect  # visti orfani due volte di fila
        if confirmed & {"dashboard", "calendar"}:
            confirmed.add("closer")  # senza popup il closer non serve mai
        if confirmed:
            with window_lock() as ok:
                if not ok:
                    suspect = orphans  # apertura in corso: si riprova dopo
                    continue
                # ricontrollo sotto lock: nel frattempo popup.sh può aver
                # completato un'apertura legittima
                still = find_orphans() & confirmed
                if still & {"dashboard", "calendar"}:
                    still.add("closer")
                aw = active_windows()
                wins = set(aw) if aw is not None else set()
                if still & wins:
                    log_action(f"watchdog: chiudo orfani {sorted(still & wins)}")
                    eww("close", *sorted(still & wins))
                if still & {"dashboard", "calendar", "closer"}:
                    eww("update", "popup=", "reveal-dashboard=false", "reveal-calendar=false",
                        "power-confirm=", "expand-wifi=false", "expand-bt=false")
            orphans -= confirmed
        suspect = orphans


def close_popup_if_open(reason=""):
    if eww_get("popup"):
        log_action(f"chiudo il popup: {reason}")
        subprocess.Popen([os.path.join(DIR, "scripts", "popup.sh"), "close"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


# ------------------------------------------------------- 2. barre per monitor
def monitor_count():
    try:
        return len(json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"], text=True)))
    except Exception:
        return 1


def sync_bars():
    with window_lock(wait=10) as ok:
        if not ok:
            return False  # sync_bars_retry riproverà
        n = monitor_count()
        wins = active_windows()
        if wins is None:
            return False  # eww non risponde: niente aperture/chiusure alla cieca
        for i in range(n):
            if f"bar-{i}" not in wins:
                eww("open", "bar", "--id", f"bar-{i}", "--arg", f"monitor={i}")
                # il client si arrende dopo ~135 ms ma il daemon continua a
                # costruire la barra: si aspetta che ci sia davvero, così la
                # prossima apertura non si accavalla (TEST_REPORT B2)
                end = time.monotonic() + 5
                while time.monotonic() < end and f"bar-{i}" not in (active_windows() or {}):
                    time.sleep(0.1)
        for wid, name in wins.items():
            if name == "bar" and wid.startswith("bar-"):
                try:
                    if int(wid[4:]) >= n:
                        eww("close", wid)
                except ValueError:
                    pass
        return True


def sync_bars_retry(attempts=8):
    """sync_bars finché eww risponde (al massimo ~attempts*1.5 s)."""
    for _ in range(attempts):
        if sync_bars():
            return True
        time.sleep(1.5)
    return False


def watch_hyprland():
    last_active = [None]  # indirizzo dell'ultima finestra con il focus
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not sig:
        return
    path = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "hypr", sig, ".socket2.sock")
    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.connect(path)
                buf = b""
                while chunk := s.recv(4096):
                    buf += chunk
                    *lines, buf = buf.split(b"\n")
                    if any(l.startswith((b"monitoradded", b"monitorremoved")) for l in lines):
                        time.sleep(1.5)  # lascia che GTK veda il nuovo output
                        sync_bars_retry()
                    # cambio workspace o finestra con il focus: chiudi il popup.
                    # Attenzione: Hyprland rimanda "activewindowv2" anche quando
                    # cambia solo il TITOLO della finestra attiva (terminale con
                    # spinner, schede del browser...): conta solo un indirizzo nuovo.
                    changed = ""
                    for l in lines:
                        if l.startswith(b"workspacev2>>"):
                            changed = "cambio workspace " + l.decode(errors="replace")
                        elif l.startswith(b"activewindowv2>>"):
                            addr = l.split(b">>", 1)[1].strip()
                            if addr and addr != b"," and addr != last_active[0]:
                                if last_active[0] is not None:
                                    changed = "cambio finestra " + addr.decode(errors="replace")
                                last_active[0] = addr
                    # EWW_NO_EVENT_CLOSE: solo per le istanze di TEST, che ricevono
                    # gli eventi dell'Hyprland vero (l'utente che cambia finestra
                    # chiuderebbe i popup di prova). La barra vera non lo imposta.
                    if changed and not os.environ.get("EWW_NO_EVENT_CLOSE"):
                        close_popup_if_open(changed)
        except OSError:
            time.sleep(2)


# ------------------------------------------------------- 4. salute del daemon
def config_of(pid):
    """Config dir di un processo eww (dalla sua riga di comando)."""
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            args = f.read().decode(errors="replace").split("\0")
    except OSError:
        return None
    for i, a in enumerate(args):
        if a in ("-c", "--config") and i + 1 < len(args):
            return os.path.realpath(args[i + 1])
        if a.startswith("--config="):
            return os.path.realpath(a.split("=", 1)[1])
    return os.path.realpath(os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "eww"))


def listening_pids():
    """PID di processi con un socket unix in ascolto (da `ss -xlp`)."""
    try:
        out = subprocess.run(["ss", "-xlpH"], capture_output=True, text=True, timeout=3).stdout
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None
    pids = set()
    for part in out.split("pid=")[1:]:
        num = part.split(",", 1)[0]
        if num.isdigit():
            pids.add(int(num))
    return pids


def our_daemons():
    """Daemon eww di QUESTA config: processi 'eww' con un socket in ascolto."""
    listening = listening_pids()
    if listening is None:
        return None
    found = []
    for d in os.listdir("/proc"):
        if not d.isdigit():
            continue
        try:
            with open(f"/proc/{d}/comm") as f:
                if f.read().strip() != "eww":
                    continue
        except OSError:
            continue
        if int(d) in listening and config_of(d) == os.path.realpath(DIR):
            found.append(int(d))
    return found


def ping_ok():
    try:
        return subprocess.run([*EWW, "ping"], capture_output=True, text=True, timeout=3).returncode == 0
    except subprocess.TimeoutExpired:
        return False


def request_recovery(reason):
    subprocess.Popen(["setsid", "-f", os.path.join(DIR, "scripts", "recover.sh")],
                     env={**os.environ, "REASON": reason},
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


MEM_LIMIT_MB = int(os.environ.get("EWW_MEM_LIMIT_MB", 400))  # oltre: riavvio (B5)
MEM_EVERY = int(os.environ.get("EWW_MEM_EVERY", 60))         # secondi tra controlli
# dopo un riavvio per memoria, il successivo solo dopo MEM_COOLDOWN secondi:
# se la RAM di base superasse il limite, eviterebbe riavvii a ripetizione
MEM_COOLDOWN = int(os.environ.get("EWW_MEM_COOLDOWN", 600))
MEM_STAMP = os.environ.get("EWW_MEM_STAMP", os.path.join(CACHE, "mem-restart.stamp"))


def my_daemon_pid():
    """PID del daemon eww da cui discende questo script."""
    pid = os.getppid()
    for _ in range(10):
        try:
            with open(f"/proc/{pid}/comm") as f:
                if f.read().strip() == "eww":
                    return pid
            with open(f"/proc/{pid}/stat") as f:
                pid = int(f.read().rsplit(")", 1)[1].split()[1])
        except (OSError, ValueError, IndexError):
            return None
    return None


def rss_mb(pid):
    try:
        with open(f"/proc/{pid}/status") as f:
            for line in f:
                if line.startswith("VmRSS:"):
                    return int(line.split()[1]) // 1024
    except (OSError, ValueError):
        pass
    return 0


DUP_CHECKS = 2       # controlli consecutivi con daemon duplicati prima di intervenire
HUNG_SECONDS = 20    # daemon che non risponde da così tanto = bloccato


def health_loop():
    time.sleep(10)  # lascia finire l'avvio/reload
    dup_seen, hung_since = 0, None
    me, last_mem = my_daemon_pid(), time.monotonic()
    while True:
        time.sleep(2)
        if me and time.monotonic() - last_mem >= MEM_EVERY:
            last_mem = time.monotonic()
            mb = rss_mb(me)
            if mb > MEM_LIMIT_MB and eww_get("popup") == "":
                try:
                    age = time.time() - os.path.getmtime(MEM_STAMP)
                except OSError:
                    age = None
                if age is not None and age < MEM_COOLDOWN:
                    log_action(f"RAM {mb} MB > {MEM_LIMIT_MB} MB, ma ultimo riavvio {int(age)} s fa: salto")
                else:
                    os.makedirs(CACHE, exist_ok=True)
                    with open(MEM_STAMP, "w") as f:
                        f.write(str(mb))
                    log_action(f"RAM {mb} MB > {MEM_LIMIT_MB} MB: riavvio pulito")
                    request_recovery(f"RAM del daemon {mb} MB > {MEM_LIMIT_MB} MB")
                    return
        ds = our_daemons()
        if ds is not None and len(ds) > 1:
            dup_seen += 1
            if dup_seen >= DUP_CHECKS:
                request_recovery(f"daemon duplicati {ds}")
                return
        else:
            dup_seen = 0
        if ping_ok():
            hung_since = None
        else:
            hung_since = hung_since or time.monotonic()
            if time.monotonic() - hung_since > HUNG_SECONDS:
                request_recovery(f"daemon non risponde da {HUNG_SECONDS}s")
                return


# ------------------------------------------------------------- 5. systray
WATCHER = ["--dest", "org.kde.StatusNotifierWatcher", "--object-path", "/StatusNotifierWatcher"]


def _gdbus(*args):
    try:
        return subprocess.run(["gdbus", "call", "--session", *args],
                              capture_output=True, text=True, timeout=3).stdout
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return ""


def tray_resync():
    """Registra gli elementi del systray presenti su D-Bus ma non nel watcher.
    Ritorna l'elenco dei nomi registrati (per i test)."""
    registered = _gdbus(*WATCHER, "--method", "org.freedesktop.DBus.Properties.Get",
                        "org.kde.StatusNotifierWatcher", "RegisteredStatusNotifierItems")
    if not registered:
        return []  # nessun watcher (eww non ancora pronto)
    try:
        names = subprocess.run(["busctl", "--user", "list", "--no-legend"],
                               capture_output=True, text=True, timeout=3).stdout
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return []
    done = []
    for line in names.splitlines():
        name = line.split()[0] if line.split() else ""
        if not name.startswith("org.kde.StatusNotifierItem-"):
            continue
        owner = _gdbus("--dest", "org.freedesktop.DBus", "--object-path", "/org/freedesktop/DBus",
                       "--method", "org.freedesktop.DBus.GetNameOwner", name)
        owner = owner.strip().strip("()',")
        if not owner or f"'{owner}/" in registered or f"'{owner}'" in registered or f"'{name}" in registered:
            continue
        _gdbus(*WATCHER, "--method", "org.kde.StatusNotifierWatcher.RegisterStatusNotifierItem", name)
        done.append(name)
    return done


def tray_loop():
    time.sleep(4)
    while True:
        try:
            tray_resync()
        except Exception:
            pass
        time.sleep(30)


# ------------------------------------------------------------- 3. batteria
def battery():
    for path in sorted(glob.glob("/sys/class/power_supply/BAT*")):
        try:
            with open(f"{path}/capacity") as f:
                cap = int(f.read())
            with open(f"{path}/status") as f:
                return cap, f.read().strip()
        except (OSError, ValueError):
            continue
    return None


def notify(title, body, urgency="normal", icon="battery"):
    subprocess.run(["notify-send", "-a", "Batteria", "-u", urgency, "-i", icon, title, body],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def load_history():
    try:
        with open(HISTORY) as f:
            data = json.load(f)
        now = time.time()
        return [(t, v) for t, v in data if now - t <= HISTORY_SPAN]
    except (OSError, ValueError, TypeError):
        return []


def save_history(hist):
    os.makedirs(CACHE, exist_ok=True)
    tmp = HISTORY + ".tmp"
    with open(tmp, "w") as f:
        json.dump(hist, f)
    os.replace(tmp, HISTORY)


def publish_history(hist):
    with out_lock:
        state["battery"] = [v for _, v in hist]
        span = int((time.time() - hist[0][0]) / 60) if hist else 0
        state["battery_span"] = f"{span} min" if span < 60 else "1 ora"
    emit()


def battery_loop():
    sent = set()
    hist = load_history()
    last_sample = hist[-1][0] if hist else 0
    while True:
        b = battery()
        now = time.time()
        if b:
            cap, status = b
            charging = status in ("Charging", "Full")
            if charging:
                sent -= {"low", "critical"}
                if cap >= 100 and "full" not in sent:
                    notify("Batteria carica", "Puoi scollegare l'alimentatore.", icon="battery-full-charged")
                    sent.add("full")
            else:
                sent.discard("full")
                if cap <= 5 and "critical" not in sent:
                    notify("Batteria quasi scarica!", f"{cap}% rimasto: collega subito l'alimentatore.",
                           urgency="critical", icon="battery-empty")
                    sent.update({"critical", "low"})
                elif cap <= 15 and "low" not in sent:
                    notify("Batteria bassa", f"{cap}% rimasto.", icon="battery-low")
                    sent.add("low")

            if now - last_sample >= SAMPLE_EVERY or not hist:
                hist = [(t, v) for t, v in hist if now - t <= HISTORY_SPAN] + [(now, cap)]
                last_sample = now
                save_history(hist)
                publish_history(hist)
        time.sleep(ALERT_EVERY)


def main():
    emit()
    threading.Thread(target=battery_loop, daemon=True).start()
    cleanup_orphans()
    threading.Thread(target=watchdog, daemon=True).start()
    threading.Thread(target=health_loop, daemon=True).start()
    threading.Thread(target=tray_loop, daemon=True).start()
    sync_bars_retry()
    watch_hyprland()  # blocca: resta in ascolto degli eventi di Hyprland
    while True:       # fuori da Hyprland: resta comunque vivo
        time.sleep(3600)


if __name__ == "__main__":
    main()
