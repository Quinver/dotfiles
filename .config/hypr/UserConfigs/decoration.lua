-- UserConfigs/decoration.lua
-- Rounding here is only the fallback: the Quickshell theme sets rounding and
-- border colours at runtime (hyprctl eval) and pushes them again on reload.

hl.config({
    decoration = {
        rounding = 0,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        dim_inactive     = false,  -- keep games and video at full brightness

        -- Soft, wide drop shadow, slightly lower than the window so it reads
        -- as depth instead of a dark outline. Lighter on unfocused windows.
        shadow = {
            enabled        = true,
            range          = 18,
            render_power   = 3,
            offset         = { 0, 4 },
            color          = "rgba(000000aa)",
            color_inactive = "rgba(00000055)",
        },

        -- Blur behind anything translucent (terminal, shell panels, menus).
        -- https://wiki.hypr.land/Configuring/Variables/#blur
        blur = {
            enabled           = true,
            size              = 6,
            passes            = 3,
            noise             = 0.02,
            contrast          = 0.9,
            brightness        = 0.85,
            vibrancy          = 0.17,
            vibrancy_darkness = 0.1,
            popups            = true,   -- right-click menus and tooltips too
            new_optimizations = true,
            xray              = false,
        },
    },
})
