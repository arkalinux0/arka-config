#!/usr/bin/env python3
import os
import json
import glob

def get_fan_rpms():
    # Find the coretemp hwmon directory
    hwmon_path = None
    for path in glob.glob('/sys/class/hwmon/hwmon*/name'):
        try:
            with open(path, 'r') as f:
                if f.read().strip() == 'asus':
                    hwmon_path = os.path.dirname(path)
                    break
        except Exception:
            continue
    
    if not hwmon_path:
        return None

    rpms = {}
    # Find all temp*_label files
    labels = glob.glob(os.path.join(hwmon_path, 'fan*_label'))
    for label_path in labels:
        try:
            with open(label_path, 'r') as f:
                label = f.read().strip()
                if label in ("cpu_fan", "gpu_fan"):
                    input_path = label_path.replace('_label', '_input')
                    if os.path.exists(input_path):
                        with open(input_path, 'r') as f_in:
                            rpms["cpu" if label == "cpu_fan" else "gpu"] = int(f_in.read().strip())
        except Exception:
            continue
    
    if not rpms:
        return None
    
    # Waybar Custom Module JSON format
    return {
        "text": f"✇  {rpms['cpu']} | {rpms['gpu']}",
        "tooltip": f"CPU Fan: {rpms['cpu']} RPM\nGPU Fan: {rpms['gpu']} RPM",
    }

if __name__ == "__main__":
    result = get_fan_rpms()
    if result:
        print(json.dumps(result))
