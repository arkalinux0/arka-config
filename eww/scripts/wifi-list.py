#!/usr/bin/env python3
"""Reti Wi-Fi visibili (defpoll, solo con la lista aperta) in JSON.
SSID passato agli script in base64: niente problemi con spazi o apici."""
import base64
import json
import subprocess


def run(*cmd):
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL, timeout=5)
    except Exception:
        return ""


def split_terse(line):
    # nmcli -t: i ':' dentro i valori sono escapati come '\:'
    out, cur, esc = [], "", False
    for ch in line:
        if esc:
            cur += ch; esc = False
        elif ch == "\\":
            esc = True
        elif ch == ":":
            out.append(cur); cur = ""
        else:
            cur += ch
    out.append(cur)
    return out


saved = set(run("nmcli", "-t", "-f", "NAME", "con", "show").splitlines())
nets = {}
for line in run("nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "no").splitlines():
    parts = split_terse(line)
    if len(parts) < 4 or not parts[1]:
        continue
    inuse, ssid, signal, sec = parts[0] == "*", parts[1], int(parts[2] or 0), parts[3]
    n = nets.get(ssid)
    if n is None or inuse or signal > n["signal"]:
        nets[ssid] = {
            "ssid": " ".join(ssid.split()) or ssid,  # una riga (FIX_LOG N2); b64 = originale
            "b64": base64.b64encode(ssid.encode()).decode(),
            "signal": signal,
            "secure": sec not in ("", "--"),
            "active": inuse or (n["active"] if n else False),
            "saved": ssid in saved,
        }

items = sorted(nets.values(), key=lambda n: (not n["active"], not n["saved"], -n["signal"]))[:10]
print(json.dumps(items))
