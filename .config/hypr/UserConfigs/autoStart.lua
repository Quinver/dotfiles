-- UserConfigs/autoStart.lua
-- Was: autoStart.conf
-- exec-once = ... → hl.on("hyprland.start", ...) so each command runs
-- only once per session, not on every config reload.

hl.on("hyprland.start", function()
    -- Desktop shell (Quickshell): bar, wallpaper, notifications, launcher,
    -- OSD and theming all live in ~/.config/quickshell.
    hl.exec_cmd("qs")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("firefox")

    -- Open discord on workspace 7 silently (no focus switch).
    hl.exec_cmd("discord --ozone-platform-hint=auto --enable-wayland-ime --wayland-text-input-version=3", {
        workspace = "7 silent",

    })
    
    hl.exec_cmd("systemctl --user start fcitx5")

    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")

    -- Clipboard history
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

-- Commented-out evsieve line preserved for reference:
-- hl.on("hyprland.start", function()
--     hl.exec_cmd([[evsieve --input "$(grep -l 'Wireless Controller' /sys/class/input/event*/device/name | head -n 1 | awk -F/ '{print "/dev/input/"$5}')" --hook key:%316 exec-shell="BATT=\$(upower -i \$(upower -e | grep 'ps_controller' | head -n 1) | grep 'percentage:' | awk '{print \$2}'); notify-send 'Button Pressed!' \"Controller Battery: \$BATT\""]])
-- end)
