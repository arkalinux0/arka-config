#!/usr/bin/env python3
"""
Player MPRIS FINTO su D-Bus, per i test (nessun audio).
  python3 fake-mpris.py <nome> <stato> <artista> <titolo> [secondi]
Espone org.mpris.MediaPlayer2.<nome> con PlaybackStatus e Metadata dati;
resta attivo per [secondi] (default 6) e poi sparisce.
"""
import sys
import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

name, status, artist, title = sys.argv[1:5]
secs = float(sys.argv[5]) if len(sys.argv) > 5 else 6

XML = """<node>
 <interface name="org.mpris.MediaPlayer2">
  <property name="Identity" type="s" access="read"/>
  <property name="CanQuit" type="b" access="read"/>
  <property name="CanRaise" type="b" access="read"/>
  <property name="HasTrackList" type="b" access="read"/>
  <property name="DesktopEntry" type="s" access="read"/>
  <property name="SupportedUriSchemes" type="as" access="read"/>
  <property name="SupportedMimeTypes" type="as" access="read"/>
 </interface>
 <interface name="org.mpris.MediaPlayer2.Player">
  <method name="PlayPause"/><method name="Play"/><method name="Pause"/>
  <method name="Next"/><method name="Previous"/><method name="Stop"/>
  <property name="PlaybackStatus" type="s" access="read"/>
  <property name="Metadata" type="a{sv}" access="read"/>
  <property name="CanPlay" type="b" access="read"/>
  <property name="CanPause" type="b" access="read"/>
  <property name="CanControl" type="b" access="read"/>
  <property name="Position" type="x" access="read"/>
 </interface>
</node>"""


def get_prop(conn, sender, path, iface, prop):
    vals = {
        "Identity": GLib.Variant("s", "Fake " + name), "CanQuit": GLib.Variant("b", False),
        "CanRaise": GLib.Variant("b", False), "HasTrackList": GLib.Variant("b", False),
        "DesktopEntry": GLib.Variant("s", ""), "SupportedUriSchemes": GLib.Variant("as", []),
        "SupportedMimeTypes": GLib.Variant("as", []),
        "PlaybackStatus": GLib.Variant("s", status),
        "Metadata": GLib.Variant("a{sv}", {
            "mpris:trackid": GLib.Variant("o", "/org/mpris/MediaPlayer2/Track/1"),
            "xesam:title": GLib.Variant("s", title),
            "xesam:artist": GLib.Variant("as", [artist] if artist else []),
        }),
        "CanPlay": GLib.Variant("b", True), "CanPause": GLib.Variant("b", True),
        "CanControl": GLib.Variant("b", True), "Position": GLib.Variant("x", 0),
    }
    return vals.get(prop)


def on_call(conn, sender, path, iface, method, params, inv):
    inv.return_value(None)


node = Gio.DBusNodeInfo.new_for_xml(XML)
bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
for iface in node.interfaces:
    bus.register_object("/org/mpris/MediaPlayer2", iface, on_call, get_prop, None)
Gio.bus_own_name_on_connection(bus, "org.mpris.MediaPlayer2." + name, Gio.BusNameOwnerFlags.NONE, None, None)
loop = GLib.MainLoop()
GLib.timeout_add(int(secs * 1000), loop.quit)
loop.run()
