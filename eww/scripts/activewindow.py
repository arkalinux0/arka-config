#!/usr/bin/env python3
"""
Uso risorse della finestra attiva (deflisten), letto direttamente da
/proc invece che via SNMP. Somma il processo e tutti i suoi figli
(utile per browser ed editor che usano molti processi).
Output: {"class": "firefox", "title": "...", "cpu": 12.5, "ram": "812 MB", "procs": 9}
"""
import json
import os
import subprocess
import time

INTERVAL = 2
TICK = os.sysconf("SC_CLK_TCK")
PAGE = os.sysconf("SC_PAGE_SIZE")
EMPTY = {"class": "", "title": "", "cpu": 0, "ram": "—", "procs": 0}


def proc_table():
    """pid -> (ppid, cpu_ticks, rss_bytes)"""
    table = {}
    for d in os.listdir("/proc"):
        if not d.isdigit():
            continue
        try:
            with open(f"/proc/{d}/stat") as f:
                stat = f.read()
        except OSError:
            continue
        fields = stat[stat.rfind(")") + 2:].split()
        # fields[0] = state, [1] = ppid, [11] = utime, [12] = stime, [21] = rss
        table[int(d)] = (int(fields[1]), int(fields[11]) + int(fields[12]), int(fields[21]) * PAGE)
    return table


def tree(root, table):
    children = {}
    for pid, (ppid, _, _) in table.items():
        children.setdefault(ppid, []).append(pid)
    out, stack = [], [root]
    while stack:
        p = stack.pop()
        if p in table:
            out.append(p)
            stack.extend(children.get(p, []))
    return out


def fmt_bytes(b):
    for unit in ("B", "KB", "MB", "GB"):
        if b < 1024 or unit == "GB":
            return f"{b:.0f} {unit}" if unit in ("B", "KB", "MB") else f"{b:.2f} GB"
        b /= 1024


def main():
    prev_ticks, prev_t, prev_pid = None, time.monotonic(), None
    last = None
    while True:
        try:
            win = json.loads(subprocess.check_output(["hyprctl", "activewindow", "-j"], text=True) or "{}")
        except Exception:
            win = {}
        pid = win.get("pid", -1)
        out = dict(EMPTY)
        if pid and pid > 0:
            table = proc_table()
            pids = tree(pid, table)
            ticks = sum(table[p][1] for p in pids)
            now = time.monotonic()
            cpu = 0.0
            if prev_pid == pid and prev_ticks is not None:
                cpu = max(ticks - prev_ticks, 0) / TICK / (now - prev_t) * 100
            prev_ticks, prev_t, prev_pid = ticks, now, pid
            out = {
                # tab/a capo -> spazi: il dashboard mostra sempre una riga (FIX_LOG N2)
                "class": " ".join(str(win.get("class", "")).split()),
                "title": " ".join(str(win.get("title", "")).split()),
                "cpu": round(cpu, 1),
                "ram": fmt_bytes(sum(table[p][2] for p in pids)),
                "procs": len(pids),
            }
        s = json.dumps(out)
        if s != last:
            last = s
            print(s, flush=True)
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
