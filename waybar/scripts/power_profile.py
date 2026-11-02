import json
import subprocess

def get_power_profile():
    profile = subprocess.check_output(["powerprofilesctl", "get"], text=True).strip()
    profile = profile[0].upper() + profile[1:]

    icon = "⚡" if profile == "Performance" else "⚖️" if profile == "Balanced" else "🔋"

    return {
        "text": f"{icon}  {profile}"
    }

if __name__ == "__main__":
    result = get_power_profile()
    if result:
        print(json.dumps(result))
