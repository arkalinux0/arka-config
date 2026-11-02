-- ============================================================
-- input.lua — Tastiera, touchpad, dispositivi, gesture
-- ============================================================

hl.config({
    input = {
        kb_layout  = "ch,ru",
        kb_variant = "fr,",
        kb_model   = "",
        kb_options = "grp:alt_shift_toggle",
        kb_rules   = "",

        follow_mouse = 1,
        sensitivity  = 0,   -- -1.0 .. 1.0, 0 = nessuna modifica

        touchpad = {
            natural_scroll       = false,
            clickfinger_behavior = true,
            disable_while_typing = false
        },
    },
})

-- Gesture: 3 dita orizzontale → cambia workspace
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Dispositivi specifici
hl.device({ name = "epic-mouse-v1",               sensitivity = -0.5 })
hl.device({ name = "at-translated-set-2-keyboard" })
