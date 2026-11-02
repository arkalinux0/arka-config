#!/usr/bin/env python3
import os
import json
import glob

def get_cpu_temp():
    # Find the coretemp hwmon directory
    hwmon_path = None
    for path in glob.glob('/sys/class/hwmon/hwmon*/name'):
        try:
            with open(path, 'r') as f:
                if f.read().strip() == 'coretemp':
                    hwmon_path = os.path.dirname(path)
                    break
        except Exception:
            continue
    
    if not hwmon_path:
        return None

    temps = []
    # Find all temp*_label files
    labels = glob.glob(os.path.join(hwmon_path, 'temp*_label'))
    for label_path in labels:
        try:
            with open(label_path, 'r') as f:
                label = f.read().strip()
                # Only average files explicitly labeled as "Core"
                if 'Core' in label:
                    input_path = label_path.replace('_label', '_input')
                    if os.path.exists(input_path):
                        with open(input_path, 'r') as f_in:
                            temps.append(int(f_in.read().strip()) / 1000.0)
        except Exception:
            continue
    
    if not temps:
        return None
        
    avg_temp = round(sum(temps) / len(temps))
    max_temp = round(max(temps))
    
    # Define icon based on temperature
    icon = ""
    if avg_temp >= 80:
        icon = "🔥"
    
    # Waybar Custom Module JSON format
    return {
        "text": f"{icon}  {avg_temp}",
        "tooltip": f"Average: {avg_temp}°C\nMax Core: {max_temp}°C\nCores tracked: {len(temps)}",
        "class": "critical" if avg_temp >= 80 else "normal"
    }

if __name__ == "__main__":
    result = get_cpu_temp()
    if result:
        print(json.dumps(result))
