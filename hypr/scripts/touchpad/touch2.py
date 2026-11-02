import os

DEVICE = "elan2514:00-04f3:43db"  # touchscreen

state = os.path.exists(os.path.join(os.path.dirname(__file__), "no-touchscreen"))

if state:
    os.system(f"hyprctl eval 'hl.device({{ name = \"{DEVICE}\", enabled = true }})'")
    os.remove(os.path.join(os.path.dirname(__file__), "no-touchscreen"))
    os.system('hyprctl notify 1 3000 0 "Touchscreen enabled"')
else:
    os.system(f"hyprctl eval 'hl.device({{ name = \"{DEVICE}\", enabled = false }})'")
    open(os.path.join(os.path.dirname(__file__), "no-touchscreen"), "w").write("")
    os.system('hyprctl notify 1 3000 0 "Touchscreen disabled"')
