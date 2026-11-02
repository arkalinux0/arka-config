import os

os.chdir(os.path.dirname(__file__))

os.system("cp -f config.jsonc configs/config.jsonc")
os.system("cp -f config.jsonc configs/config-no-workspaces.jsonc")

os.chdir("configs")

no_workspaces_config = ""
remove = 0
for line in open("config-no-workspaces.jsonc", "r").read().splitlines():
    if "\"modules-center\"" in line:
        remove = 3
        continue
    if "\"hyprland/workspaces\":" in line:
        remove = 33
        continue
    if remove > 0:
        remove -= 1
        continue
    no_workspaces_config += line + "\n"

no_workspaces_config = no_workspaces_config.replace("\"height\": 40", "\"height\": 46")

open("config-no-workspaces.jsonc", "w").write(no_workspaces_config)
