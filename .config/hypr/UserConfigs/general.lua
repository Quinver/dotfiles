-- UserConfigs/general.lua
-- Was: general.conf

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 10,

        border_size = 3,

        -- Gradient borders: "rgba(a) rgba(b) 45deg" → table form
        col = {
            active_border = {
                colors = { "rgba(5c8374ff)", "rgba(7FA79AFF)" },
                angle  = 45,
            },
            inactive_border = "rgba(595959aa)",
        },

        resize_on_border = true,
        extend_border_grab_area = 15,
        allow_tearing    = false,
        layout           = "dwindle",
    },
    cursor = {
        hide_on_key_press = true,
    },
})
