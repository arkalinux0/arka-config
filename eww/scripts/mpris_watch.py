#!/usr/bin/env python3
"""
Ascolto dei cambiamenti MPRIS via D-Bus (usato da media.py e cava.py).

Perché (TEST_REPORT B4): `playerctl --follow` segue un player alla volta e a
volte non vede quelli che compaiono o spariscono: la barra si accorgeva della
musica con 3-9 s di ritardo. Qui si ascoltano direttamente i segnali D-Bus:
  - NameOwnerChanged su org.mpris.MediaPlayer2.*  (player avviato / chiuso)
  - PropertiesChanged su /org/mpris/MediaPlayer2  (play/pausa, brano)
A ogni evento si chiama `callback()`, raggruppando gli eventi a raffica
(al massimo una chiamata ogni `debounce` secondi, l'ultima sempre eseguita).

watch(callback) ritorna False se Gio non è disponibile: il chiamante usa
allora il vecchio metodo (playerctl --follow).
"""
import threading
import time


def watch(callback, debounce=0.1):
    try:
        import gi
        gi.require_version("Gio", "2.0")
        from gi.repository import Gio, GLib
    except (ImportError, ValueError):
        return False

    pending = threading.Event()

    def worker():
        while True:
            pending.wait()
            time.sleep(debounce)  # raggruppa gli eventi ravvicinati
            pending.clear()
            try:
                callback()
            except Exception:
                pass

    def on_signal(*_args):
        pending.set()

    ready = threading.Event()
    ok = [False]

    def loop():
        try:
            bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
            bus.signal_subscribe(
                "org.freedesktop.DBus", "org.freedesktop.DBus", "NameOwnerChanged",
                "/org/freedesktop/DBus", "org.mpris.MediaPlayer2",
                Gio.DBusSignalFlags.MATCH_ARG0_NAMESPACE, on_signal)
            bus.signal_subscribe(
                None, "org.freedesktop.DBus.Properties", "PropertiesChanged",
                "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player",
                Gio.DBusSignalFlags.NONE, on_signal)
            ok[0] = True
        except Exception:
            ready.set()
            return
        ready.set()
        GLib.MainLoop().run()

    threading.Thread(target=worker, daemon=True).start()
    threading.Thread(target=loop, daemon=True).start()
    ready.wait(5)
    return ok[0]
