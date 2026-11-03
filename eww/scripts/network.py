#!/usr/bin/env python3
"""
Rete per eww (deflisten), aggiornata ogni secondo.
Output:
{
  "primary": "wlan0", "down": "1.2 MB/s", "up": "30 KB/s", "vpn": true,
  "wifi": {"enabled": true, "ssid": "Casa", "signal": 70},
  "ifaces": [{"name": "wlan0", "kind": "wifi", "up": true, "ipv4": "...",
              "ipv6": "...", "down": "...", "up_rate": "..."}]
}
"""
import json
import os
import signal
import subprocess
import time

WIFI_EVERY = 5
VPN_PREFIXES = ("proton", "wg", "tun", "tap", "ppp", "nordlynx", "tailscale")


def run(*cmd):
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL, timeout=3)
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
        return ""


def fmt(bps):
    if bps >= 1024 ** 2:
        return f"{bps / 1024 ** 2:.1f} MB/s"
    if bps >= 1024:
        return f"{bps / 1024:.0f} KB/s"
    return f"{bps:.0f} B/s"


def counters(name):
    try:
        with open(f"/sys/class/net/{name}/statistics/rx_bytes") as f:
            rx = int(f.read())
        with open(f"/sys/class/net/{name}/statistics/tx_bytes") as f:
            tx = int(f.read())
        return rx, tx
    except OSError:
        return None


def kind(name, link_type):
    if name.startswith(VPN_PREFIXES):
        return "vpn"
    if name.startswith(("wl", "wlan")):
        return "wifi"
    if name.startswith(("en", "eth")):
        return "ethernet"
    if name.startswith(("virbr", "docker", "br-", "veth", "ipv6leak")):
        return "virtual"
    return link_type or "other"


def primary_iface():
    out = run("ip", "route", "get", "1.1.1.1").split()
    return out[out.index("dev") + 1] if "dev" in out else ""


def wifi_info():
    enabled = run("nmcli", "-t", "radio", "wifi").strip() == "enabled"
    info = {"enabled": enabled, "ssid": "", "signal": 0, "band": "", "rate": "", "channel": ""}
    if enabled:
        # SSID per ultimo: può contenere ':'
        for line in run("nmcli", "-t", "-f", "ACTIVE,SIGNAL,FREQ,RATE,CHAN,SSID",
                        "dev", "wifi", "list", "--rescan", "no").splitlines():
            parts = line.split(":", 5)
            if len(parts) == 6 and parts[0] in ("yes", "sì"):
                freq = int((parts[2].split() or ["0"])[0] or 0)
                info.update(
                    ssid=" ".join(parts[5].replace("\\:", ":").split()), signal=int(parts[1] or 0),
                    band="6 GHz" if freq >= 5925 else "5 GHz" if freq >= 4900 else "2.4 GHz" if freq else "",
                    rate=parts[3].replace("Mbit/s", "Mb/s").strip(), channel=parts[4])
                break
    return info


def slow_info():
    """Dati che cambiano di rado (aggiornati insieme al Wi-Fi):
    MAC fisici, gateway, DNS."""
    perm = {}
    try:
        for l in json.loads(run("ip", "-j", "link") or "[]"):
            if l.get("permaddr"):
                perm[l["ifname"]] = l["permaddr"]
    except json.JSONDecodeError:
        pass
    gateway, gw_dev = "", ""
    try:
        routes = json.loads(run("ip", "-j", "route", "show", "default") or "[]")
        if routes:
            gateway, gw_dev = routes[0].get("gateway", ""), routes[0].get("dev", "")
    except json.JSONDecodeError:
        pass
    dns = []
    try:
        with open("/etc/resolv.conf") as f:
            dns = [l.split()[1] for l in f if l.startswith("nameserver") and len(l.split()) > 1]
    except OSError:
        pass
    return {"perm": perm, "gateway": gateway or "—", "gw_dev": gw_dev, "dns": ", ".join(dns[:3]) or "—"}


def is_random_mac(mac):
    # bit "locally administered" del primo byte: MAC generato via software
    try:
        return bool(int(mac.split(":")[0], 16) & 0x02)
    except (ValueError, IndexError):
        return False


PIDFILE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "eww-network.pid")
force_wifi = False


def on_usr1(*_):
    global force_wifi
    force_wifi = True


def main():
    global force_wifi
    signal.signal(signal.SIGUSR1, on_usr1)
    with open(PIDFILE, "w") as f:
        f.write(str(os.getpid()))
    prev, prev_t = {}, time.monotonic()
    wifi, wifi_t = wifi_info(), time.monotonic()
    slow = slow_info()
    while True:
        now = time.monotonic()
        dt = max(now - prev_t, 0.001)
        prev_t = now
        if force_wifi or now - wifi_t >= WIFI_EVERY:
            force_wifi = False
            wifi, wifi_t = wifi_info(), now
            slow = slow_info()

        try:
            links = json.loads(run("ip", "-j", "addr") or "[]")
        except json.JSONDecodeError:
            links = []

        primary = primary_iface()
        ifaces, cur = [], {}
        for link in links:
            name = link.get("ifname", "")
            if name == "lo":
                continue
            c = counters(name)
            cur[name] = c
            rx = tx = 0
            if c and prev.get(name):
                rx = max(c[0] - prev[name][0], 0) / dt
                tx = max(c[1] - prev[name][1], 0) / dt
            v4 = [a["local"] + "/" + str(a["prefixlen"]) for a in link.get("addr_info", []) if a.get("family") == "inet"]
            v6 = [a["local"] for a in link.get("addr_info", [])
                  if a.get("family") == "inet6" and a.get("scope") == "global"]
            flags = link.get("flags", [])
            mac = link.get("address") or ""
            if link.get("link_type") not in ("ether", "ieee802.11"):
                mac = ""  # VPN/tunnel: niente MAC
            perm = slow["perm"].get(name, "")
            ifaces.append({
                "name": name,
                "kind": kind(name, link.get("link_type", "")),
                "up": "UP" in flags and "NO-CARRIER" not in flags,
                "primary": name == primary,
                "ipv4": ", ".join(v4) or "—",
                "ipv6": ", ".join(v6),
                "mac": mac or "—",
                # MAC casuale (privacy di NetworkManager): si mostra anche quello fisico
                "mac_random": bool(mac) and is_random_mac(mac),
                "mac_hw": perm if perm and perm != mac else "",
                "down": fmt(rx), "up_rate": fmt(tx),
                "_rx": rx, "_tx": tx,
            })
        prev = cur

        # interfaccia principale prima, poi quelle attive, poi il resto
        ifaces.sort(key=lambda i: (not i["primary"], not i["up"], i["name"]))
        p = next((i for i in ifaces if i["primary"]), None)
        out = {
            "primary": primary,
            "primary_kind": p["kind"] if p else "",
            "down": p["down"] if p else "—",
            "up": p["up_rate"] if p else "—",
            "vpn": any(i["kind"] == "vpn" and i["up"] for i in ifaces),
            "wifi": wifi,
            "gateway": slow["gateway"],
            "gw_dev": slow["gw_dev"],
            "dns": slow["dns"],
            "ifaces": [{k: v for k, v in i.items() if not k.startswith("_")} for i in ifaces],
        }
        print(json.dumps(out), flush=True)
        time.sleep(0.2 if force_wifi else 1)


if __name__ == "__main__":
    main()
