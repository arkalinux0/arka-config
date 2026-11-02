#!/usr/bin/env python3
import os
import json
import glob

def get_cpu_data():
    data = {}
    total_freq = 0

    cores = glob.glob("/sys/bus/cpu/devices/cpu*")
    for core in cores:
        try:
            max_freq = int(open(os.path.join(core, 'cpufreq', 'scaling_max_freq'), "r").read().strip()) / 10**3 # result in MHz
            cur_freq = int(open(os.path.join(core, 'cpufreq', 'scaling_cur_freq'), "r").read().strip()) / 10**3
            total_freq += cur_freq
            data[os.path.basename(core).removeprefix("cpu")] = {"cur": cur_freq, "max": max_freq}
        except:
            pass

    if not data:
        return None

    avg_freq = total_freq / len(cores)
    data_keys = []
    for core in data.keys():
        data_keys.append(int(core))
    data_keys = sorted(data_keys)
    str_data_keys = []
    for core in data_keys:
        str_data_keys.append(str(core))
    data_keys = str_data_keys
    del str_data_keys
    
    # Waybar Custom Module JSON format
    return {
        "text": f"⏱  {round(avg_freq)} MHz",
        "tooltip": "\n".join(f'Core {core}: {data[core]["cur"]} / {data[core]["max"]} MHz' for core in data_keys),
    }

if __name__ == "__main__":
    result = get_cpu_data()
    if result:
        print(json.dumps(result))
