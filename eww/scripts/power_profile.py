#!/usr/bin/env python3
import subprocess


def get_power_profile():
    try:
        profile = subprocess.check_output(["powerprofilesctl", "get"], text=True).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None

    if not profile:
        # Comando riuscito ma output vuoto: evita l'IndexError su profile[0]
        return None

    profile = profile[0].upper() + profile[1:]  # Metti la prima lettera in maiuscolo

    # Assegna un'icona in base al profilo
    icon = "⚡" if profile == "Performance" else "⚖️" if profile == "Balanced" else "🔋"

    return f"{icon}  {profile}"


if __name__ == "__main__":
    result = get_power_profile()
    if result:
        print(result)
