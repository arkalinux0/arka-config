-- ============================================================
-- autostart.lua — Programmi avviati all'avvio
-- ============================================================

hl.on("hyprland.start", function()
    -- Keyring e GTK
    hl.exec_cmd("/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh")
    hl.exec_cmd('gsettings set org.gnome.desktop.interface gtk-theme "Materia-dark"')
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")

    -- File manager daemon e terminale
    hl.exec_cmd("thunar -q")
    hl.exec_cmd("kitty")
    -- hl.exec_cmd("/home/arka/Arch.sh")
    -- hl.exec_cmd("/home/arka/Arch2.sh")

    -- Bar, wallpaper, clipboard
    hl.exec_cmd("eww open-many bar secondary")
    -- hl.exec_cmd("waybar")
    hl.exec_cmd("waypaper --restore")
    hl.exec_cmd("copyq")
    hl.exec_cmd("conky")

    -- Cursore e polkit
    hl.exec_cmd("hyprctl setcursor catppuccin-mocha-mauve-cursors 28")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")

    -- Notifiche e rete
    hl.exec_cmd("swaync")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("protonvpn-app")

    -- Script touchpad
    hl.exec_cmd("python /home/arka/.config/hypr/scripts/touchpad/touch1.py")

    -- Overlay scanlines
    hl.exec_cmd("sh ~/.config/hypr/overlays/scanlines.sh")
end)
