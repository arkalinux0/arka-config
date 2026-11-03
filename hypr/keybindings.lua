-- ============================================================
-- keybindings.lua — Tutti i tasti
-- ============================================================

local mainMod     = "SUPER"
local terminal    = "kitty"
local terminal2   = "foot -a footp"
local fileManager = "nemo"
local menu        = "vicinae toggle"


-- ---- Utilità generali ---------------------------------------

hl.bind(mainMod .. " + B",     hl.dsp.exec_cmd("~/bin/notify-time"))
-- hl.bind(mainMod .. " + L",     hl.dsp.exec_cmd("sh /home/arka/Arch2.sh"))
hl.bind(mainMod .. " + T",     hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q",     hl.dsp.window.close())
hl.bind(mainMod .. " + M",     hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + E",     hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + F",     hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R",     hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + J",     hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + K",     hl.dsp.exec_cmd("hyprctl kill"))
hl.bind(mainMod .. " + X",     hl.dsp.exec_cmd("pkill waybar"))
hl.bind(mainMod .. " + H",     hl.dsp.exec_cmd("kitty --class layout python /home/arka/.config/hypr/scripts/layout-switcher/main.py"))


-- ---- Popup e app rapide -------------------------------------

hl.bind(mainMod .. " + P",           hl.dsp.exec_cmd("~/.local/bin/fastfetch-popup"))
hl.bind(mainMod .. " + V",           hl.dsp.exec_cmd("copyq toggle"))
hl.bind(mainMod .. " + N",           hl.dsp.exec_cmd("swaync-client -t -sw"))
hl.bind(mainMod .. " + SPACE",       hl.dsp.exec_cmd("foot -a btop btop"))
hl.bind(mainMod .. " + C",           hl.dsp.exec_cmd("kitty --class tty-clock /usr/bin/tty-clock -scf '%A %d.%m.%Y'"))
hl.bind(mainMod .. " + Y",           hl.dsp.exec_cmd("EDITOR=nano kitty yazi"))
hl.bind(mainMod .. " + CTRL + C",    hl.dsp.exec_cmd("kitty --class cava /usr/bin/cava"))
hl.bind(mainMod .. " + CTRL + M",    hl.dsp.exec_cmd("~/user_scripts/wlogout/wlogout_scale.sh"))
hl.bind(mainMod .. " + W",           hl.dsp.exec_cmd("python /home/arka/.config/waybar/scripts/toggle-waybar-stats/main.py"))
hl.bind(mainMod .. " + G",           hl.dsp.exec_cmd('foot -a workspace --title "Lista Finestre" sh -c "python /home/arka/.local/lista_finestre.py; echo; read -n 1"'))
hl.bind(mainMod .. " + SHIFT + T",   hl.dsp.exec_cmd(terminal2))
-- ---- Web -----------------------------------------------

hl.bind("CTRL + SHIFT + W",          hl.dsp.exec_cmd("zen-browser --blank-window https://web.whatsapp.com/")) -- zen-browser --blank-window per falli aprire una finestra vuota
hl.bind(mainMod .. " + SHIFT + code:201", hl.dsp.exec_cmd("zen-browser"))
hl.bind("CTRL + W",                  hl.dsp.exec_cmd("/home/arka/.config/waybar/scripts/toggle-workspaces/execute.sh"))
hl.bind(mainMod .." + CTRL + SHIFT + M",    hl.dsp.exec_cmd("/home/arka/.config/fish/scripts/school-time.fish 0 m"))
hl.bind(mainMod .." + CTRL + SHIFT + S",    hl.dsp.exec_cmd("/home/arka/.config/fish/scripts/school-time.fish 0"))
hl.bind("CTRL + SHIFT + T",          hl.dsp.exec_cmd("zen-browser --blank-window https://teams.cloud.microsoft/"))
-- ---- Lock / sospensione ------------------------------------
hl.bind(mainMod .. " + L",	     hl.dsp.exec_cmd("hyprlock"))
-- hl.bind("CTRL + ALT + S",            hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + CTRL + L",    hl.dsp.exec_cmd("hyprlock & systemctl suspend"), { locked = true })


-- ---- Screenshot --------------------------------------------

hl.bind("CTRL + Y",       hl.dsp.exec_cmd("grim -g \"$(slurp)\" ~/Pictures/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"))
hl.bind("CTRL + SHIFT + Y", hl.dsp.exec_cmd("grim ~/Pictures/fullscreen-$(date +'%Y-%m-%d_%H-%M-%S').png"))


-- ---- Touchpad / hardware -----------------------------------

hl.bind("F11",            hl.dsp.exec_cmd("python /home/arka/.config/hypr/scripts/touchpad/touch2.py"))
hl.bind("XF86Launch2",    hl.dsp.exec_cmd("python /home/arka/.config/hypr/scripts/touchpad/main.py"))


-- ---- Dashboard eww ------------------------------------------
-- Apre/chiude il dashboard sul monitor con il focus
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("~/.config/eww/scripts/popup.sh dashboard"))

-- ---- Volume (OSD di eww) -----------------------------------
-- Prima ogni tasto era legato due volte (con e senza OSD): scattavano
-- entrambi i bind, quindi il volume cambiava del 10% invece del 5%.
local osd = "~/.config/eww/scripts/osd.sh"
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ && " .. osd .. " volume"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && " .. osd .. " volume"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && " .. osd .. " volume"),     { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })

-- Luminosità
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+ && " .. osd .. " brightness"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%- && " .. osd .. " brightness"), { locked = true, repeating = true })

-- Media player
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })


-- ---- Movimento focus ----------------------------------------

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))


-- ---- Ridimensionamento (SUPER + CAPS + frecce) --------------

hl.bind(mainMod .. " + CAPS + left",  hl.dsp.window.resize({ x = -15, y = 0, relative = true }),  { repeating = true })
hl.bind(mainMod .. " + CAPS + right", hl.dsp.window.resize({ x = 15,  y = 0, relative = true }),  { repeating = true })
hl.bind(mainMod .. " + CAPS + up",    hl.dsp.window.resize({ x = 0,   y = -15, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CAPS + down",  hl.dsp.window.resize({ x = 0,   y = 15, relative = true }),  { repeating = true })


-- ---- Swap finestre (SUPER + ALT + frecce) -------------------

hl.bind(mainMod .. " + ALT + right", hl.dsp.window.swap({ direction = "right" }))
hl.bind(mainMod .. " + ALT + left",  hl.dsp.window.swap({ direction = "left" }))
hl.bind(mainMod .. " + ALT + up",    hl.dsp.window.swap({ direction = "up" }))
hl.bind(mainMod .. " + ALT + down",  hl.dsp.window.swap({ direction = "down" }))


-- ---- Workspace [1-10] ---------------------------------------

for i = 1, 10 do
    local key = i % 10   -- 10 → tasto 0
    hl.bind(mainMod .. " + " .. key,           hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i }))
end


-- ---- Navigazione workspace personalizzata (script) ----------

local ws = "/home/arka/.config/hypr/scripts/movetoworkspace/execute.sh"

hl.bind(mainMod .. " + CTRL + right",         hl.dsp.exec_cmd(ws .. " + workspace true"))   -- workspace esistente avanti
hl.bind(mainMod .. " + CTRL + left",          hl.dsp.exec_cmd(ws .. " - workspace true"))   -- workspace esistente indietro
hl.bind(mainMod .. " + CTRL + SHIFT + right", hl.dsp.exec_cmd(ws .. " + workspace false"))  -- workspace avanti
hl.bind(mainMod .. " + CTRL + SHIFT + left",  hl.dsp.exec_cmd(ws .. " - workspace false"))  -- workspace indietro

hl.bind(mainMod .. " + SHIFT + right",        hl.dsp.exec_cmd(ws .. " + movetoworkspace false"))  -- sposta finestra avanti
hl.bind(mainMod .. " + SHIFT + left",         hl.dsp.exec_cmd(ws .. " - movetoworkspace false"))  -- sposta finestra indietro


-- ---- Switch monitor (script) --------------------------------

hl.bind(mainMod .. " + A",        hl.dsp.exec_cmd(ws .. " switchmonitor"))
hl.bind(mainMod .. " + SHIFT + A",hl.dsp.exec_cmd(ws .. " windowswitchmonitor"))


-- ---- Scratchpad ---------------------------------------------

hl.bind(mainMod .. " + S",        hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S",hl.dsp.window.move({ workspace = "special:magic" }))


-- ---- Scroll workspace con rotella ---------------------------

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))


-- ---- Trascina / ridimensiona con mouse ----------------------

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
