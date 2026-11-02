#!/usr/bin/env python3
"""
RPM delle ventole per eww.

La versione originale cercava solo un hwmon con name == "asus", quindi
su un HP Envy x360 (Intel, non Asus) non restituiva mai nulla. Qui
invece si scansionano TUTTI gli hwmon disponibili e si prendono tutti
i fan*_input validi (>0), con fallback sul nome del file se manca una
label leggibile.
"""
import glob
import os


def read(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return None


def get_fan_rpms():
    fans = []
    for input_path in sorted(glob.glob("/sys/class/hwmon/hwmon*/fan*_input")):
        rpm = read(input_path)
        if not rpm or rpm == "0":
            continue

        label_path = input_path.replace("_input", "_label")
        label = read(label_path) or os.path.basename(input_path).replace("_input", "")
        fans.append((label, rpm))

    if not fans:
        return None

    return "RPM  " + " | ".join(rpm for _, rpm in fans)


if __name__ == "__main__":
    result = get_fan_rpms()
    if result:
        print(result)
