-- UserConfigs/layouts.lua
-- Was: layouts.conf
-- Note: dwindle.pseudotile was removed in 0.55 as a config option;
--       pseudotiling is now toggled via hl.dsp.window.pseudo() (a bind)
--       or set per-window with a window rule. The commented line is preserved.

hl.config({
    dwindle = {
        -- pseudotile = true,  -- REMOVED as config key; use window rules or the pseudo dispatcher
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },
})
