import os

status = os.system("pkill -f 'waybar -c /home/arka/.config/waybar/stats.jsonc'")

if status != 0:
    os.system("hyprctl dispatch 'hl.dsp.exec_cmd(\"waybar -c ~/.config/waybar/stats.jsonc\")'")
