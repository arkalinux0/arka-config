import os

DEVICE = "syna32f5:00-06cb:cfc5-touchpad"

state = os.path.exists(os.path.join(os.path.dirname(__file__), "no-touchpad"))

if state:
    os.system(f"hyprctl eval 'hl.device({{ name = \"{DEVICE}\", enabled = true }})'")
    os.system(f"rm {os.path.join(os.path.dirname(__file__), 'no-touchpad')}")
    os.system("hyprctl notify 1 3000 0 \"Touchpad enabled\"")
else:
    os.system(f"hyprctl eval 'hl.device({{ name = \"{DEVICE}\", enabled = false }})'")
    open(os.path.join(os.path.dirname(__file__), "no-touchpad"), "w").write("")
    os.system("hyprctl notify 1 3000 0 \"Touchpad disabled\"")
