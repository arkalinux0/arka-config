import os
import subprocess
import sys

layout_file = f"/home/{os.getenv('USER')}/.config/hypr/layout.lua"
layouts = ["dwindle", "master", "scrolling"]

if len(sys.argv) >= 2:
    if sys.argv[1] == "get":
        layout = open(layout_file, "r").read().splitlines()[2].strip().split(" ")[-1]
        os.system(f"hyprctl notify 1 3000 0 \"Current layout mode: {layout}\"")
        quit()

config_text_start = "hl.config({\ngeneral = {\n    layout = "
config_text_end = "\n}\n})"

if os.path.exists(layout_file):
    layout = open(layout_file, "r").read().splitlines()[2].strip().split(" ")[-1]

    fzf_text = "\n".join(layout[0].upper() + layout[1:] for layout in layouts)

    new_layout = subprocess.check_output(["fzf"], input=fzf_text, text=True).strip("\n")

    open(layout_file, "w").write(config_text_start + '"' +  new_layout.lower() + '"' + config_text_end)
    os.system(f"hyprctl notify 1 3000 0 \"Layout mode changed to {new_layout.lower()}\"")
