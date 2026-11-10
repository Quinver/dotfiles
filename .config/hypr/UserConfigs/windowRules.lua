-- UserConfigs/windowRules.lua
-- Was: windowRules.conf
-- windowrulev2 / windowrule → hl.window_rule({ match={...}, <effects> })
--
-- Conversion notes:
--   match:class ^(pattern)$  → match = { class = "^(pattern)$" }
--   match:float 1             → match = { float = true }
--   match:tag name            → match = { tag = "name" }
--   workspace N silent        → workspace = N, follow = false
--   tag +tagname              → tag = "+tagname"   (adds tag; "-" removes)
--   stay_focused on           → stay_focused = true

-- Ensure discord always opens on workspace 7 without switching to it
hl.window_rule({
    name      = "discord-workspace",
    match     = { class = "^(discord)$" },
    workspace = 7,
})

-- DaVinci Resolve popup handling
-- Tag floating Resolve windows as "drpopup"
hl.window_rule({
    name  = "resolve-tag-popup",
    match = { class = "^(resolve)$", float = true },
    tag   = "+drpopup",
})

-- Prevent Resolve from closing the popup on mouse movement / pointer leave
hl.window_rule({
    name        = "resolve-stay-focused",
    match       = { tag = "drpopup" },
    stay_focused = true,
})

-- Skyrim Creation Kit (Steam app 1946180, Windows exe under Proton/XWayland).
-- The CK is a multi-window Win32 app: main window, Object Window, Cell View,
-- Render Window and every dialog are separate top-level windows that position
-- themselves with absolute pixel coordinates stored in CreationKitPrefs.ini.
-- Tiling scatters them, so keep all of them floating and let the CK place them.
hl.window_rule({
    name  = "creationkit-float",
    match = { class = "^(steam_app_1946180|[Cc]reation[Kk]it\\.exe)$" },
    float = true,
})

-- Several CK dialogs report a bogus max size; without this they refuse to be
-- resized past it (same reason winecfg needs nomaxsize).
hl.window_rule({
    name        = "creationkit-nomaxsize",
    match       = { class = "^(steam_app_1946180|[Cc]reation[Kk]it\\.exe)$" },
    no_max_size = true,
})

-- Stop CK's maximize requests from turning the main window into a tile.
hl.window_rule({
    name           = "creationkit-no-maximize",
    match          = { class = "^(steam_app_1946180|[Cc]reation[Kk]it\\.exe)$" },
    suppress_event = "maximize",
})

-- Give the CK a dedicated workspace so its many absolute-positioned windows
-- (main, Object Window, Cell View, UAC dialog, ...) never mix with other apps.
-- On 0.56.2 this also switches to workspace 4 when the window appears; the
-- newer `follow` field is rejected by this version ("unknown field 'follow'").
hl.window_rule({
    name      = "creationkit-workspace",
    match     = { class = "^(steam_app_1946180|[Cc]reation[Kk]it\\.exe)$" },
    workspace = 4,
})

-- ---- Creation Kit docked layout -------------------------------------------
-- Under Wine the CK's panes are separate top-level windows that are not
-- clipped to the main frame, and they restore absolute pixel coordinates, so
-- they overlap. Give each known window a fixed slot instead: menu/toolbar
-- strip on top, Object Window left, Render Window right, Cell View across the
-- bottom. Values are client-area pixels on the 1920x1080 monitor.
-- The main window has a server-side title bar (it ends up above the strip);
-- the panes have none. ck-layout.sh re-applies the same numbers after launch
-- as well, because the CK positions its panes itself right after creating them.
hl.window_rule({
    name  = "creationkit-main-strip",
    match = { class = "^(steam_app_1946180|[Cc]reation[Kk]it\\.exe)$", title = "^Creation Kit" },
    float = true,
    move  = { 4, 42 },
    size  = { 1912, 80 },
})

hl.window_rule({
    name  = "creationkit-object-window",
    match = { class = "^(steam_app_1946180|[Cc]reation[Kk]it\\.exe)$", title = "^Object Window$" },
    float = true,
    move  = { 4, 136 },
    size  = { 592, 600 },
})

hl.window_rule({
    name  = "creationkit-render-window",
    match = { class = "^(steam_app_1946180|[Cc]reation[Kk]it\\.exe)$", title = "^Render Window$" },
    float = true,
    move  = { 612, 136 },
    size  = { 1304, 600 },
})

hl.window_rule({
    name  = "creationkit-cell-view",
    match = { class = "^(steam_app_1946180|[Cc]reation[Kk]it\\.exe)$", title = "^Cell View$" },
    float = true,
    move  = { 4, 752 },
    size  = { 1912, 316 },
})

-- ---- Quality-of-life rules -------------------------------------------------
hl.window_rule({
    name  = "pip-float",
    match = { title = "^(Picture-in-Picture)$" },
    float = true,
    pin   = true,
    keep_aspect_ratio = true,
    size  = { 480, 270 },
    move  = { "monitor_w-window_w-20", "monitor_h-window_h-20" },
})

hl.window_rule({
    name  = "pavucontrol-float",
    match = { class = "^(org.pulseaudio.pavucontrol)$" },
    float = true,
    size  = { 900, 600 },
    center = true,
})

hl.window_rule({
    name  = "portal-gtk-float",
    match = { class = "^(xdg-desktop-portal-gtk)$" },
    float = true,
    center = true,
})

hl.window_rule({
    name  = "file-dialog-float",
    match = { title = "^(Open File|Save File|Open Folder)$" },
    float = true,
    center = true,
})

hl.window_rule({
    name  = "polkit-float",
    match = { class = "^(hyprpolkitagent)$" },
    float = true,
    center = true,
    pin   = true,
})

hl.window_rule({
    name  = "satty-float",
    match = { class = "^(com.gabm.satty)$" },
    float = true,
    center = true,
})
