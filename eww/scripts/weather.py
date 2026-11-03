#!/usr/bin/env python3
"""
Meteo da Open-Meteo (nessuna chiave API), una città alla volta (deflisten).
La città scelta è salvata in ~/.cache/eww/weather-city; scripts/weather-set.sh
la cambia e manda SIGUSR1 per aggiornare subito.

Output:
{"city": "Lugano", "cities": [...], "ok": true, "loading": false,
 "temp": 12, "feels": 10, "icon": "󰖙", "desc": "Sereno", "wind": 8,
 "days": [{"name": "mer", "icon": "...", "max": 14, "min": 6, "rain": 20}, ...],
 "updated": "10:30"}
"""
import json
import os
import signal
import threading
import time
import urllib.request
from datetime import date

CITIES = {
    "Lugano": (46.0037, 8.9511),
    "Bellinzona": (46.1955, 9.0170),
    "Locarno": (46.1709, 8.7995),
}
DEFAULT = "Lugano"
EVERY = 15 * 60
CACHE = os.path.expanduser("~/.cache/eww")
CITY_FILE = os.path.join(CACHE, "weather-city")
PIDFILE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "eww-weather.pid")
DAYS = ["lun", "mar", "mer", "gio", "ven", "sab", "dom"]

wake = threading.Event()

# codici WMO -> (icona giorno, icona notte, descrizione)
WMO = {
    0: ("󰖙", "󰖔", "Sereno"),
    1: ("󰖕", "󰼱", "Poco nuvoloso"),
    2: ("󰖕", "󰼱", "Parz. nuvoloso"),
    3: ("󰖐", "󰖐", "Coperto"),
    45: ("󰖑", "󰖑", "Nebbia"), 48: ("󰖑", "󰖑", "Nebbia gelata"),
    51: ("󰖗", "󰖗", "Pioviggine"), 53: ("󰖗", "󰖗", "Pioviggine"), 55: ("󰖗", "󰖗", "Pioviggine forte"),
    56: ("󰖗", "󰖗", "Pioviggine gelata"), 57: ("󰖗", "󰖗", "Pioviggine gelata"),
    61: ("󰖗", "󰖗", "Pioggia debole"), 63: ("󰖖", "󰖖", "Pioggia"), 65: ("󰖖", "󰖖", "Pioggia forte"),
    66: ("󰙿", "󰙿", "Pioggia gelata"), 67: ("󰙿", "󰙿", "Pioggia gelata"),
    71: ("󰖘", "󰖘", "Neve debole"), 73: ("󰖘", "󰖘", "Neve"), 75: ("󰼶", "󰼶", "Neve forte"),
    77: ("󰖘", "󰖘", "Nevischio"),
    80: ("󰖗", "󰖗", "Rovesci"), 81: ("󰖖", "󰖖", "Rovesci"), 82: ("󰖖", "󰖖", "Rovesci forti"),
    85: ("󰖘", "󰖘", "Rovesci di neve"), 86: ("󰼶", "󰼶", "Rovesci di neve"),
    95: ("󰖓", "󰖓", "Temporale"), 96: ("󰖓", "󰖓", "Temporale e grandine"), 99: ("󰖓", "󰖓", "Temporale e grandine"),
}


def wmo(code, day=True):
    i_day, i_night, desc = WMO.get(code, ("󰖐", "󰖐", "—"))
    return (i_day if day else i_night), desc


def current_city():
    try:
        with open(CITY_FILE) as f:
            c = f.read().strip()
        return c if c in CITIES else DEFAULT
    except OSError:
        return DEFAULT


def fetch(city):
    lat, lon = CITIES[city]
    url = ("https://api.open-meteo.com/v1/forecast"
           f"?latitude={lat}&longitude={lon}"
           "&current=temperature_2m,apparent_temperature,weather_code,is_day,wind_speed_10m"
           "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
           "&timezone=Europe%2FZurich&forecast_days=4")
    with urllib.request.urlopen(url, timeout=10) as r:
        data = json.load(r)
    cur, daily = data["current"], data["daily"]
    icon, desc = wmo(cur["weather_code"], bool(cur.get("is_day", 1)))
    days = []
    for i in range(1, len(daily["time"])):  # da domani
        d = date.fromisoformat(daily["time"][i])
        dicon, ddesc = wmo(daily["weather_code"][i])
        days.append({
            "name": DAYS[d.weekday()], "icon": dicon, "desc": ddesc,
            "max": round(daily["temperature_2m_max"][i]),
            "min": round(daily["temperature_2m_min"][i]),
            "rain": daily["precipitation_probability_max"][i] or 0,
        })
    return {
        "ok": True, "temp": round(cur["temperature_2m"]), "feels": round(cur["apparent_temperature"]),
        "icon": icon, "desc": desc, "wind": round(cur["wind_speed_10m"]),
        "today_max": round(daily["temperature_2m_max"][0]), "today_min": round(daily["temperature_2m_min"][0]),
        "days": days, "updated": time.strftime("%H:%M"),
    }


def main():
    signal.signal(signal.SIGUSR1, lambda *_: wake.set())
    os.makedirs(CACHE, exist_ok=True)
    with open(PIDFILE, "w") as f:
        f.write(str(os.getpid()))

    last = {"ok": False, "temp": "--", "icon": "󰖐", "desc": "", "days": [], "updated": ""}
    while True:
        city = current_city()
        if last.get("city") != city:  # città cambiata: niente dati vecchi di un'altra città
            last = {"ok": False, "temp": "--", "icon": "󰖐", "desc": "Caricamento…", "days": [], "updated": ""}
        print(json.dumps({**last, "city": city, "cities": list(CITIES), "loading": True}), flush=True)
        try:
            last = {**fetch(city), "city": city}
        except Exception:
            # offline: si tengono gli ultimi dati validi (se della stessa città)
            last = {**last, "city": city, "desc": last.get("desc") if last.get("ok") else "Non disponibile"}
        print(json.dumps({**last, "cities": list(CITIES), "loading": False}), flush=True)
        wake.wait(EVERY if last.get("ok") else 30)  # offline (es. all'avvio): si riprova presto
        wake.clear()


if __name__ == "__main__":
    main()
