-- UserConfigs/input.lua
-- Was: input.conf
-- Empty string values for kb_variant/model/options/rules are kept as "".
-- Nested touchpad block → nested table.
-- Standalone "device { name=... }" block → hl.device({ name=..., ... })

hl.config({
    input = {
        kb_layout  = "be",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,
        repeat_rate  = 40,
        repeat_delay = 275,

        sensitivity = 0,  -- -1.0 to 1.0; 0 = no modification

        touchpad = {
            natural_scroll = false,
        },
    },
})

-- Device-specific overrides (was a standalone device{} block)
hl.device({
    name    = "sony-interactive-entertainment-wireless-controller-touchpad",
    enabled = false,
})
