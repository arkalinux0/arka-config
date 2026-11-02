#!/usr/bin/env python3
import subprocess
import json
import time
import os

# CONFIGURATION
INTEL_RC6_PATH = "/sys/class/drm/card1/device/drm/card1/gt/gt0/rc6_residency_ms"

def get_nvidia_usage():
    try:
        res = subprocess.check_output(
            ["nvidia-smi", "--query-gpu=utilization.gpu", "--format=csv,noheader,nounits"],
            encoding='utf-8', stderr=subprocess.DEVNULL
        )
        return int(res.strip())
    except (subprocess.CalledProcessError, FileNotFoundError, ValueError):
        return None

def get_intel_usage():
    if not os.path.exists(INTEL_RC6_PATH):
        return None
        
    try:
        # We need two samples to calculate residency delta
        with open(INTEL_RC6_PATH, 'r') as f:
            rc6_start = int(f.read().strip())
        t_start = time.time()
        
        # Short wait (Waybar interval handles the rest)
        time.sleep(0.1)
        
        with open(INTEL_RC6_PATH, 'r') as f:
            rc6_end = int(f.read().strip())
        t_end = time.time()
        
        # Calculate how much time the GPU was NOT in RC6 (idle)
        elapsed_ms = (t_end - t_start) * 1000.0
        rc6_delta_ms = rc6_end - rc6_start
        
        # Percentage of time NOT idling
        usage = max(0, min(100, 100.0 - (rc6_delta_ms / elapsed_ms * 100.0)))
        return int(usage)
    except (ValueError, ZeroDivisionError, IOError):
        return None

def main():
    nvidia = get_nvidia_usage()
    intel = get_intel_usage()
    icon = "󰾲"
    
    if nvidia is not None and intel is not None:
        usage = nvidia
        usage_str = f"{intel} | {nvidia}"
    elif nvidia is not None:
        usage = nvidia
        usage_str = str(nvidia)
    elif intel is not None:
        usage = intel
        usage_str = str(intel)
    else:
        usage = 0
        usage_str = "0"

    status_class = "normal"
    if usage > 80:
        status_class = "critical"
    elif usage > 50:
        status_class = "warning"

    output = {
        "text": f"{icon}  {usage_str}",
        "tooltip": f"Intel: {intel if intel is not None else 'N/A'}%\nNVIDIA: {nvidia if nvidia is not None else 'OFF'}%",
        "class": status_class
    }
    
    print(json.dumps(output))

if __name__ == "__main__":
    main()
