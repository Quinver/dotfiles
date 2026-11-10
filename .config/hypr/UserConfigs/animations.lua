-- UserConfigs/animations.lua
-- Smooth but quick: things decelerate into place, nothing bounces.
-- speed is in deciseconds (speed 4 = 400ms). Layer animations (the Quickshell
-- bar, popouts, launcher) are left at Hyprland's defaults on purpose: the
-- shell animates those itself, and a second animation on top looks doubled.
-- Previous version: ~/shell-work/backups/hypr-*/UserConfigs/animations.lua

hl.config({ animations = { enabled = true } })

-- ── Curves ────────────────────────────────────────────────────────────────
-- Fast start, long soft landing. Used for most movement.
hl.curve("quint", { type = "bezier", points = { { 0.23, 1 },    { 0.32, 1 } } })
-- Material 3 "emphasized decelerate": a little more punch at the start.
hl.curve("md3",   { type = "bezier", points = { { 0.05, 0.7 },  { 0.1, 1 } } })
-- Symmetric ease for things that leave the screen.
hl.curve("inOut", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
-- Nearly linear, for fades.
hl.curve("fade",  { type = "bezier", points = { { 0.5, 0.5 },   { 0.75, 1 } } })
-- Kept from the old config (zoom).
hl.curve("snap",  { type = "bezier", points = { { 0.64, 0 },    { 1, 1 } } })

local function anim(leaf, speed, bezier, style)
    hl.animation({ leaf = leaf, enabled = true, speed = speed, bezier = bezier, style = style })
end

-- ── Windows ───────────────────────────────────────────────────────────────
anim("windowsIn",   4,   "quint", "popin 87%")  -- grow in from 87% size
anim("windowsOut",  2.5, "inOut", "popin 87%")  -- shrink out, a bit faster
anim("windowsMove", 4,   "quint", "slide")      -- tiling reshuffles, swaps, drags

-- ── Fades ─────────────────────────────────────────────────────────────────
anim("fadeIn",     2,   "fade")
anim("fadeOut",    1.5, "fade")
anim("fadeSwitch", 3,   "fade")   -- opacity change on focus switch
anim("fadeShadow", 3,   "fade")
anim("fadeDim",    3,   "fade")

-- ── Borders ───────────────────────────────────────────────────────────────
-- Colour cross-fade when focus moves (colours come from the Quickshell theme).
anim("border", 5, "quint")

-- ── Workspaces ────────────────────────────────────────────────────────────
anim("workspaces",       3.5, "quint", "slidefade 20%")  -- slide with a light fade
anim("specialWorkspace", 3.5, "md3",   "slidevert")      -- scratchpad drops in from above

-- ── Misc ──────────────────────────────────────────────────────────────────
anim("zoomFactor", 3, "quint")
