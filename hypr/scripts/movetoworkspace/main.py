from hyprpy import Hyprland
import sys

inst = Hyprland()

action = sys.argv[1]

try:
    dispatcher = sys.argv[2]
    existing_only = sys.argv[3] == "true"
except:
    pass

active_monitor = None

for monitor in inst.get_monitors():
    if monitor.is_focused:
        active_monitor = monitor
        break

active_workspace_id = inst.get_active_workspace().id
next_workspace_id = 99
for workspace in monitor.workspaces:
    if workspace.id > active_workspace_id:
        next_workspace_id = min(next_workspace_id, workspace.id)

last_workspace_id = 0
for workspace in monitor.workspaces:
    if workspace.id < active_workspace_id:
        last_workspace_id = max(last_workspace_id, workspace.id)

used_ids = []
for workspace in inst.get_workspaces():
    used_ids.append(workspace.id)
used_ids = sorted(used_ids)

try:
    if not existing_only:
        for possible_id in range(active_workspace_id, next_workspace_id):
            if possible_id not in used_ids:
                next_workspace_id = possible_id
                break
        
        for possible_id in range(active_workspace_id, last_workspace_id, -1):
            if possible_id not in used_ids:
                last_workspace_id = possible_id
                break
except:
    pass

min_id = 1
for id in used_ids:
    if id != min_id:
        break
    min_id += 1

if action == "+":
    max_id = 1

    for workspace in inst.get_workspaces():
        max_id = max(max_id, workspace.id)

    if next_workspace_id != 99:
        if dispatcher == "workspace":
            inst.dispatch([f"hl.dsp.focus({{ workspace = {next_workspace_id} }})"])
        elif dispatcher == "movetoworkspace":
            inst.dispatch([f"hl.dsp.window.move({{ workspace = {next_workspace_id} }})"])
    elif not existing_only:
        if dispatcher == "workspace":
            inst.dispatch([f"hl.dsp.focus({{ workspace = {max_id + 1} }})"])
        elif dispatcher == "movetoworkspace":
            inst.dispatch([f"hl.dsp.window.move({{ workspace = {max_id + 1} }})"])
elif action == "-":
    if last_workspace_id != 0:
        if dispatcher == "workspace":
            inst.dispatch([f"hl.dsp.focus({{ workspace = {last_workspace_id} }})"])
        elif dispatcher == "movetoworkspace":
            inst.dispatch([f"hl.dsp.window.move({{ workspace = {last_workspace_id} }})"])
    elif not existing_only:
        if not min_id > inst.get_active_workspace().id:
            if dispatcher == "workspace":
                inst.dispatch([f"hl.dsp.focus({{ workspace = {min_id} }})"])
            elif dispatcher == "movetoworkspace":
                inst.dispatch([f"hl.dsp.window.move({{ workspace = {min_id} }})"])
elif action == "switchmonitor":
    if active_monitor.name == "DP-1":
        inst.dispatch(["hl.dsp.focus({ monitor = 'eDP-1' })"])
    else:
        inst.dispatch(["hl.dsp.focus({ monitor = 'DP-1' })"])
elif action == "windowswitchmonitor":
    original_monitor_name = active_monitor.name
    if original_monitor_name == "DP-1":
        inst.dispatch(["hl.dsp.focus({ monitor = 'eDP-1' })"])
    else:
        inst.dispatch(["hl.dsp.focus({ monitor = 'DP-1' })"])
    
    other_monitor_active_workspace_id = inst.get_active_workspace().id
    inst.dispatch([f"hl.dsp.focus({{ monitor = '{original_monitor_name}' }})"])
    inst.dispatch(["movetoworkspace", str(other_monitor_active_workspace_id)])
    inst.dispatch([f"hl.dsp.window.move({{ workspace = '{other_monitor_active_workspace_id}' }})"])
