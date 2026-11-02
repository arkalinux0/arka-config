#!/usr/bin/env python3
"""
Uso CPU/RAM del processo della finestra attiva via SNMP.

Rispetto all'originale, qui vengono corretti due bug di sintassi che
mandavano in crash lo script non appena Hyprland riportava una finestra
senza PID valido o una risposta SNMP malformata:
  - `except KeyError, json.decoder.JSONDecodeError:` (sintassi Python 2,
    non valida in Python 3 -> SyntaxError all'avvio)
  - `print("text": f"...")` (non e' sintassi Python valida)
"""
import subprocess
import json
import time

last_values = {}
approx_timer = 0


def format_cpu_time(cpu_time_raw):
    centiseconds = cpu_time_raw % 100
    total_seconds = cpu_time_raw // 100

    hours = total_seconds // 3600
    minutes = (total_seconds % 3600) // 60
    seconds = total_seconds % 60

    parts = []
    if hours:
        parts.append(f"{hours}h")
    if minutes:
        parts.append(f"{minutes}m")
    if seconds:
        parts.append(f"{seconds}s")
    parts.append(f"{centiseconds}cs")
    return " ".join(parts)


def get_resource_usage():
    global last_values, approx_timer

    pid = json.loads(
        subprocess.check_output(["hyprctl", "activewindow", "-j"], text=True)
    )["pid"]

    cpu_time_raw = int(subprocess.check_output(
        ["snmpget", "-Oqv", "-v2c", "-c", "comm", "localhost",
         f"1.3.6.1.2.1.25.5.1.1.1.{pid}"], text=True
    ).strip())
    cpu_time_text = format_cpu_time(cpu_time_raw)

    ram_usage = int(subprocess.check_output(
        ["snmpget", "-OUqv", "-v2c", "-c", "comm", "localhost",
         f"1.3.6.1.2.1.25.5.1.1.2.{pid}"], text=True
    ))

    ram_units = ("KB", "MB", "GB")
    i = 0
    while ram_usage >= 1024 and i < len(ram_units) - 1:
        ram_usage /= 1024
        i += 1

    values = (cpu_time_text, round(ram_usage, 2))
    if last_values.get(pid) is not None and values != last_values[pid]:
        approx_timer = 29
    last_values = {pid: values}

    suffix = f" ({approx_timer}s)" if approx_timer else ""
    return f"pCPU  {cpu_time_text} | pRAM  {round(ram_usage, 2)} {ram_units[i]}{suffix}"


if __name__ == "__main__":
    while True:
        try:
            result = get_resource_usage()
            if result:
                print(result, flush=True)
        except (KeyError, json.decoder.JSONDecodeError):
            print(f"({approx_timer}s)" if approx_timer else "", flush=True)
        except Exception:
            pass
        time.sleep(1)
        approx_timer = max(approx_timer - 1, 0)
