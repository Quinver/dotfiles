-- UserConfigs/keybinds.lua
-- Was: keybinds.conf
-- See https://wiki.hypr.land/Configuring/Binds/
--
-- Conversion notes:
--   bind  = MOD, KEY, disp, ...   → hl.bind("MOD + KEY", hl.dsp.*(...))
--   bindm = MOD, mouse:N, disp    → hl.bind("MOD + mouse:N", hl.dsp.*(), { mouse=true })
--   bindel= ..., exec, cmd        → hl.bind(..., hl.dsp.exec_cmd(...), { repeating=true })
--   bindl = ..., exec, cmd        → hl.bind(..., hl.dsp.exec_cmd(...), { locked=true })
--   killactive                    → hl.dsp.window.close()  (NOT .kill() — that SIGKILLs)
--   exit                          → hl.dsp.exit()
--   togglefloating                → hl.dsp.window.float({ action="toggle" })
--   pin                           → hl.dsp.window.pin()
--   pseudo (dwindle)              → hl.dsp.window.pseudo()
--   fullscreen                    → hl.dsp.window.fullscreen()
--   movefocus, l/r/u/d            → hl.dsp.focus({ direction="left/right/up/down" })
--   movewindow, l/r/u/d           → hl.dsp.window.move({ direction="left/right/up/down" })
--   resizeactive, dx dy           → hl.dsp.window.resize({ delta={dx,dy} })
--   workspace, N / e+1 / e-1      → hl.dsp.focus({ workspace=N/"e+1"/"e-1" })
--   movetoworkspace, N            → hl.dsp.window.move({ workspace=N })
--   movetoworkspace, special:name → hl.dsp.window.move({ workspace="special:name" })
--   togglespecialworkspace, name  → hl.dsp.workspace.toggle_special("name")

-- ── The "super" modifier ───────────────────────────────────────────────────
-- Two chords count as super: the Super (Windows) key, and Ctrl+Alt. Remote
-- input — KDE Connect, RDP/VNC clients, KVM-over-IP — very often eats or drops
-- the Super key (a Windows host swallows it before it ever reaches us), while
-- Ctrl+Alt is the one chord those clients forward intact. So every super combo
-- below is registered twice, under both mods.
local mainMods = { "SUPER", "CTRL + ALT" }

-- hl.bind() takes a single mod string, so a combo has to be registered once per
-- alias. `make` is a factory so each bind gets its own dispatcher object.
-- Pass alias = false for combos that already contain CTRL: under the alias they
-- would need CTRL twice and could never fire, so those stay Super-only.
local function bindSuper(combo, make, opts, alias)
    local mods = alias == false and { mainMods[1] } or mainMods
    for _, mod in ipairs(mods) do
        hl.bind(mod .. " + " .. combo, make(), opts)
    end
end

-- ── App launchers ──────────────────────────────────────────────────────────
-- https://wiki.hypr.land/Configuring/Binds/
bindSuper("RETURN", function() return hl.dsp.exec_cmd(terminal) end)
bindSuper("C",      function() return hl.dsp.window.close() end)  -- graceful close (was killactive)
-- bindSuper("SHIFT + E", function() return hl.dsp.exit() end)
bindSuper("E",      function() return hl.dsp.exec_cmd(fileManager) end)
bindSuper("V",      function() return hl.dsp.window.float({ action = "toggle" }) end)
bindSuper("P",      function() return hl.dsp.window.pin() end)
bindSuper("D",      function() return hl.dsp.exec_cmd(menu) end)
bindSuper("G",      function() return hl.dsp.window.pseudo() end)  -- dwindle pseudo

-- was: bind = $mainMod, T, togglesplit (commented out originally, kept commented)
-- bindSuper("T", function() return hl.dsp.layout("togglesplit") end)

-- ── Screenshots ────────────────────────────────────────────────────────────
bindSuper("S",
    function() return hl.dsp.exec_cmd("grim - | wl-copy") end)   -- full screen to clipboard

bindSuper("SHIFT + S",
    function() return hl.dsp.exec_cmd([[wayfreeze & PID=$!; sleep .1; grim -g "$(slurp)" - | wl-copy; kill $PID]]) end)   -- region to clipboard

-- Region screenshot -> satty annotation (SUPER+SHIFT+S is taken above)
bindSuper("CTRL + S",
    function() return hl.dsp.exec_cmd([[sh -c 'grim -g "$(slurp)" - | satty --filename - --copy-command wl-copy --early-exit']]) end, nil, false)   -- region to satty editor

-- Colour picker
bindSuper("SHIFT + C",
    function() return hl.dsp.exec_cmd("hyprpicker -a") end)

-- ── qocr (Japanese OCR overlay) ────────────────────────────────────────────
-- Hover highlights a line, middle-click looks it up, click dismisses the popup.
-- The text boxes auto-hide after 10s of pointer inactivity (autoHideDelay in
-- ~/.config/qocr/config.json) and return the moment you move the mouse, so a
-- game stays unobstructed while deliberate hovering still works.
-- Hyprland's spawn PATH does not include ~/.local/bin (it comes from .zshrc,
-- which only affects terminals), so qocr must be called by absolute path or
-- the bind fails silently with "command not found".
local function qocr(cmd)
    return function() return hl.dsp.exec_cmd("~/.local/bin/qocr ipc call ocr " .. cmd) end
end

bindSuper("R",         qocr("scan"))   -- drag a region, then hover
bindSuper("SHIFT + R", qocr("scan_output $(hyprctl -j activeworkspace | jq -r .monitor)"))
bindSuper("W",         qocr("clear_all"))       -- forget region + text
bindSuper("Y",         qocr("toggle_config showOverlay"))  -- boxes on/off
bindSuper("U",         qocr("close_popup"))     -- dismiss popup

-- ── System ─────────────────────────────────────────────────────────────────
bindSuper("SHIFT + O",
    function() return hl.dsp.exec_cmd("systemctl suspend") end)

-- ── Shell (Quickshell) ─────────────────────────────────────────────────────
-- Everything goes through `qs ipc call shell <function> [args]`.
local function shell(args)
    return function() return hl.dsp.exec_cmd("qs ipc call shell " .. args) end
end

bindSuper("SHIFT + D", shell("overlay launcher"))    -- launcher (type = to calculate)
bindSuper("A",         shell("popout control"))      -- control centre
bindSuper("N",         shell("popout notifications"))
bindSuper("X",         shell("overlay power"))       -- power menu
bindSuper("B",         shell("safe"))                -- safe theme on/off
bindSuper("T",         shell("overlay themes"))     -- theme studio
bindSuper("SHIFT + T", shell("nextTheme"))
bindSuper("COMMA",     shell("overlay settings"))   -- global settings
bindSuper("SHIFT + W", shell("wallpaper next"))
bindSuper("SHIFT + V", shell("popout clipboard"))   -- clipboard history (SUPER+V is float toggle)
bindSuper("TAB",       shell("overlay overview"))   -- window overview
bindSuper("SLASH",     shell("overlay keys"))       -- keybind cheatsheet
bindSuper("M",         shell("overlay mixer"))      -- volume mixer
bindSuper("SHIFT + G", shell("overlay games"))      -- game library
bindSuper("SHIFT + P", shell("overlay docker"))      -- docker + VMs
hl.bind("CTRL + SHIFT + ESCAPE", hl.dsp.exec_cmd("qs ipc call shell overlay tasks"))   -- task manager
hl.bind("Print", hl.dsp.exec_cmd("qs ipc call shell overlay capture"))   -- screenshot / record

-- ── Fullscreen ─────────────────────────────────────────────────────────────
bindSuper("F", function() return hl.dsp.window.fullscreen() end)

-- ── Focus (HJKL) ───────────────────────────────────────────────────────────
bindSuper("H", function() return hl.dsp.focus({ direction = "left" }) end)
bindSuper("L", function() return hl.dsp.focus({ direction = "right" }) end)
bindSuper("K", function() return hl.dsp.focus({ direction = "up" }) end)
bindSuper("J", function() return hl.dsp.focus({ direction = "down" }) end)

-- ── Workspace keys by keycode ──────────────────────────────────────────────
-- The number row is bound by physical key (code:10 … code:19 = the 1 … 0 keys),
-- not by keysym, so it works on any layout. On AZERTY those keys produce
-- & é " ' ( - è _ ç à without Shift, so binding "1".."0" would never fire.
local function wsKey(i) return "code:" .. (9 + i) end   -- i = 1..10 (10 = the 0 key)

-- ── Switch workspaces (mainMod + 1-0) ──────────────────────────────────────
for i = 1, 10 do
    bindSuper(wsKey(i), function() return hl.dsp.focus({ workspace = i }) end)
end

-- ── Move window to workspace (mainMod + SHIFT + 1-0) ───────────────────────
for i = 1, 10 do
    bindSuper("SHIFT + " .. wsKey(i), function() return hl.dsp.window.move({ workspace = i }) end)
end

-- ── Move window position (HJKL) ────────────────────────────────────────────
bindSuper("SHIFT + H", function() return hl.dsp.window.move({ direction = "left" }) end)
bindSuper("SHIFT + L", function() return hl.dsp.window.move({ direction = "right" }) end)
bindSuper("SHIFT + K", function() return hl.dsp.window.move({ direction = "up" }) end)
bindSuper("SHIFT + J", function() return hl.dsp.window.move({ direction = "down" }) end)

-- ── Resize window (CTRL + HJKL) ────────────────────────────────────────────
-- Super-only: the Ctrl+Alt alias would need CTRL twice (see bindSuper).
bindSuper("CTRL + H", function() return hl.dsp.window.resize({ x = -50, y = 0 , relative= true}) end, nil, false)   -- shrink width
bindSuper("CTRL + L", function() return hl.dsp.window.resize({ x = 50, y = 0, relative= true }) end, nil, false)   -- grow width
bindSuper("CTRL + K", function() return hl.dsp.window.resize({ x = 0, y = -50, relative= true }) end, nil, false)   -- shrink height
bindSuper("CTRL + J", function() return hl.dsp.window.resize({ x = 0, y =  50, relative= true }) end, nil, false)   -- grow height

-- ── Special workspace (scratchpad) ─────────────────────────────────────────
bindSuper("SPACE",         function() return hl.dsp.workspace.toggle_special("magic") end)
bindSuper("SHIFT + SPACE", function() return hl.dsp.window.move({ workspace = "special:magic" }) end)

-- ── Move / resize windows with mouse drag (was bindm) ──────────────────────
bindSuper("mouse:272", function() return hl.dsp.window.drag() end,   { mouse = true })
bindSuper("mouse:273", function() return hl.dsp.window.resize() end, { mouse = true })

-- ── Volume / brightness (was bindel — repeating + locked) ──────────────────
hl.bind("XF86AudioRaiseVolume",
    hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
    { repeating = true, locked = true })

hl.bind("XF86AudioLowerVolume",
    hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { repeating = true, locked = true })

hl.bind("XF86AudioMute",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    { repeating = true, locked = true })

hl.bind("XF86AudioMicMute",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    { repeating = true, locked = true })

-- ── Media keys (was bindl — locked only, no repeat) ────────────────────────
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),         { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"),   { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"),   { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),     { locked = true })
