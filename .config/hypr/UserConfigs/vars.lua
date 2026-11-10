-- UserConfigs/vars.lua
-- Was: vars.conf
-- ENV variables (hl.env replaces "env = NAME, VALUE")

hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_STYLE_OVERRIDE", "kvantum")

hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")

-- User variables (was $name = value; now plain Lua locals).
-- Because each require()'d file is its own scope, export the values
-- you need in other files via the shared _G table so they remain
-- accessible across files.
terminal = "alacritty"
fileManager = "nemo"
menu = "qs ipc call shell overlay launcher"
