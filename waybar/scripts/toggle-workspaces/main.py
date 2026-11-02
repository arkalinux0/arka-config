import os

if os.path.exists("no-workspaces"):
    os.remove("no-workspaces")
    os.remove("config.jsonc")
    os.system("cp configs/config.jsonc config.jsonc")
else:
    os.system("cp configs/config-no-workspaces.jsonc config.jsonc")
    os.system("touch no-workspaces")

os.system("pkill waybar || true && hyprctl dispatch 'hl.dsp.exec_cmd(\"waybar\")'")
