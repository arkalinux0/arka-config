#!/usr/bin/env python3
"""RPM di tutte le ventole hwmon (defpoll). Output: "2300 · 2100 RPM" oppure ""."""
import glob

rpms = []
for path in sorted(glob.glob("/sys/class/hwmon/hwmon*/fan*_input")):
    try:
        with open(path) as f:
            v = f.read().strip()
    except OSError:
        continue
    if v and v != "0":
        rpms.append(v)

print(" · ".join(rpms) + " RPM" if rpms else "")
