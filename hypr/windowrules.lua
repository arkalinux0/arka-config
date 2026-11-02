-- ============================================================
-- windowrules.lua — Regole per le finestre
-- ============================================================


-- ---- Opacità ------------------------------------------------

--hl.window_rule({
--    name             = "foot-opacity",
--    match            = { class = "foot" },
--    opacity = "0.60 0.65"
--})

-- NOTA: l'originale aveva active_opacity = 2.0 (fuori range), corretto a 1.0
hl.window_rule({
    name             = "brave-opacity",
    match            = { class = "brave-browser" },
    opacity = "2.0 0.95"
})


-- ---- Popup float --------------------------------------------

hl.window_rule({
    name  = "layout",
    match = { class = "layout" },
    float = true,
    size  = "670 163"
})

hl.window_rule({
    name  = "tty-clock-float",
    match = { class = "tty-clock" },
    float = true,
    size  = "516 260"
})

hl.window_rule({
   name  = "footp",
   match = { class = "footp" },
   float = true,
   size  = "1100 818"
})

hl.window_rule({
   name  = "Lain",
   match = { class = "footp" },
   float = true,
   size  = "1025 794"
})

hl.window_rule({
    name  = "cava-float",
    match = { class = "cava" },
    float = true,
    size = "500 250"
})

hl.window_rule({
    name  = "btop-float",
    match = { class = "btop" },
    float = true,
    size  = "690 505"
})

hl.window_rule({
    name  = "fastfetch-float",
    match = { class = "fastfetchpopup" },
    float = true,
    size  = "1100 818"
})

hl.window_rule({
    name  = "workspace-float",
    match = { class = "workspace" },
    float = true,
    size  = "500 250"
})


-- ---- Varie --------------------------------------------------

hl.window_rule({
    name       = "matengine-rgbx",
    match      = { class = "MateEngineX.x86_64" },
    force_rgbx = true,
})

-- Regole per permettere l'interazione con le finestre Eww
return {
    -- Evita che Hyprland applichi animazioni o blocchi l'input sulle finestre di eww
    { "windowrulev2", "noanim, class:^(eww)$" },
    { "windowrulev2", "float, class:^(eww)$" },
}
