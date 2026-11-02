#!/usr/bin/env python3
"""
Velocita' di rete (down/up) dell'interfaccia con la default route,
aggiornata ogni secondo. Pensato per stare nella barra secondaria.
"""
import subprocess
import time


def default_iface():
    try:
        out = subprocess.check_output(
            ["ip", "route", "get", "1.1.1.1"], text=True
        ).split()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None

    if "dev" in out:
        return out[out.index("dev") + 1]
    return None


def read_bytes(iface):
    try:
        with open(f"/sys/class/net/{iface}/statistics/rx_bytes") as f:
            rx = int(f.read())
        with open(f"/sys/class/net/{iface}/statistics/tx_bytes") as f:
            tx = int(f.read())
        return rx, tx
    except OSError:
        return None


def fmt_rate(bytes_per_sec):
    if bytes_per_sec >= 1024 * 1024:
        return f"{bytes_per_sec / 1024 / 1024:.1f}MB/s"
    if bytes_per_sec >= 1024:
        return f"{bytes_per_sec / 1024:.0f}KB/s"
    return f"{bytes_per_sec:.0f}B/s"


def main():
    iface = default_iface()
    prev = read_bytes(iface) if iface else None

    while True:
        time.sleep(1)
        iface = default_iface()

        if not iface:
            print("NET  --", flush=True)
            prev = None
            continue

        cur = read_bytes(iface)
        if cur is None or prev is None:
            prev = cur
            continue

        rx_rate = cur[0] - prev[0]
        tx_rate = cur[1] - prev[1]
        prev = cur

        print(f"NET  \u2193{fmt_rate(rx_rate)} \u2191{fmt_rate(tx_rate)} ({iface})", flush=True)


if __name__ == "__main__":
    main()
