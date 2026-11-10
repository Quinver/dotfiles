---
name: quickshell
description: The user's custom Quickshell desktop shell (bar, popouts, launcher, OSD, notifications, wallpapers, themes) at ~/.config/quickshell on Arch + Hyprland. Use whenever the user mentions quickshell, "my shell", the bar, a popout/panel, the launcher, themes, wallpapers, the safe theme, or desktop colours — before reading any shell code.
---

# Quickshell desktop shell

From-scratch Quickshell 0.3.2 (`qs`, Qt 6) config for Hyprland 0.57 (**Lua config**). No ready-made shells, ever — we write it ourselves.

| Path | What |
|---|---|
| `~/.config/quickshell/` | **Live** shell. Edits hot-reload instantly on the user's screen. |
| `~/.config/quickshell/settings.json` | User config: `global` options + `themes`. Hand-editable, live-reloaded; the shell also writes it. |
| `~/shell-work/docs/SPEC.md` | Architecture, design rules, widget list, gotchas. **Read before writing QML.** |
| `~/shell-work/docs/API.md` | Quickshell API for the *installed* build. Trust it over memory. |
| `~/shell-work/shell/` | Scratch mirror for subagents/probes. Re-sync: `rm -rf ~/shell-work/shell && cp -a ~/.config/quickshell ~/shell-work/shell` |
| `~/shell-work/backup/` | Pre-rewrite configs + settings.json backups. Back up settings.json here before bulk edits. |
| `~/shell-work/tools/` | `gen_safe_wallpapers.py` (greyscale "safe" set), `gen_theme_wallpapers.py` (coloured themes via gradient map), `gen_api.py` |
| `~/.local/state/quickshell/by-shell/*/state.json` | Runtime state (current theme, wallpaper per theme, dnd, rotatePaused). |

## Map of the code

```
shell.qml            entry: per-screen Background/Bar/PopoutHost, overlays, IpcHandler "shell"
config/Settings.qml  Settings.opt(key, fallback) = theme option > global > fallback; setTheme/setOption/setThemeOption/setState
config/Theme.qml     resolved tokens: colours (bg surface surfaceHi surfaceTop outline outlineDim fg fgDim fgMuted
                     primary onPrimary primaryDim secondary tertiary error warn ok), rounding, pad, spacing, gap,
                     barHeight, fontSize/Small/Large/Huge, anim/animFast/animSlow, alpha(c,a)
config/Palette.js    OKLCH palette from one seed colour; pickSeed(); ansi() terminal colours
config/Icons.qml     Nerd Font glyph names — only use names that exist here (add new ones here)
services/*.qml       singletons (Wallpapers, SystemTheme, Audio, Net, Bt, Media, Notifs, Windows, SysInfo, Llm, AiUsage, Ui, ...)
widgets/*.qml        Txt Icon Box Btn Toggle Slider Field Meter Graph ListItem Header Sep BarButton AppIcon
bar/<Name>Module.qml loaded by name from barLeft/barCenter/barRight in settings
popouts/<Name>Panel.qml  opened via Ui.toggle("name") / BarButton { popout: "name" }; host draws frame+padding
overlays/*.qml       Launcher, PowerMenu, Osd, NotificationPopups (listed in shell.qml)
```

IPC: `qs ipc call shell <popout|overlay|close|theme|nextTheme|safe|wallpaper|currentTheme> [arg]`. Keybinds live in `~/.config/hypr/UserConfigs/keybinds.lua` (Super+A control centre, N notifications, X power, B safe, T next theme, Shift+W next wallpaper, Shift+D launcher, Shift+V clipboard history popout (cliphist via services/Clipboard.qml), Ctrl+S satty region screenshot, Shift+C hyprpicker). A popout opened by keybind/IPC appears under its bar button on the focused monitor (BarButtons with `popout:` register in `Ui.buttons`); with no such button it falls back to the right edge.
SystemTheme pushes the palette to Hyprland borders/rounding (`hyprctl eval`, Lua) and Alacritty (`~/.cache/qshell/alacritty.toml`) and writes `~/.cache/qshell/colors.json`, plus adw-gtk3/libadwaita `@define-color` overrides to `~/.config/gtk-{3,4}.0/gtk.css` (global option `gtkTint`, default true) and gsettings color-scheme/gtk-theme on mode change.

## Themes

A theme is pure data in `settings.json` → `themes.<name>`:

```json
"tide": {
  "label": "Tide",
  "wallpapers": "~/Pictures/Wallpapers/tide",
  "colors": { "source": "wallpaper" },          // wallpaper | seed (+ "seed": "#hex") | mono
  "palette": { "primary": "#hex" },             // optional per-role overrides
  "options": { "mode": "dark", "chroma": 1.0, "border": 2, "rotateInterval": 900 }
}
```

Any global option can be overridden in `options` (`mode` dark/light, `chroma`, `rounding`, `border`, `barHeight`, `font`, `fontSize`, `gap`, `pad`, `barOpacity`, `panelOpacity`, `animSpeed`, `rotate*`, `iconStyle`, bar layout...). Theme pickers (ControlPanel, WallpapersPanel) list `Settings.themeNames` automatically — no QML change needed.

Current themes: `anime` (user's own wallpapers, colours from wallpaper), `safe` (mono, greyscale generated art — the "someone is looking at my screen" theme, toggled by `qs ipc call shell safe`; keep it non-anime and neutral), `ember`, `tide`, `moss`, `paper` (light), `neon`.

**Add a theme:** add a ramp + compositions to `THEMES` in `~/shell-work/tools/gen_theme_wallpapers.py`, run `python3 ~/shell-work/tools/gen_theme_wallpapers.py <name>` (~15 s per theme), then add the block to settings.json (edit with a small python json script, keep tab indentation, back up first). Verify the palette with the headless ColorQuantizer probe below rather than switching the user's live theme.

## User taste (non-negotiable)

- Dislikes rounding: code default is 0, themes may raise it; always use `Theme.rounding` / `Theme.roundingSmall`. No pills, no decorative circles, no round avatars/art.
- All colours and sizes from `Theme` — never literal hex in QML (palette changes at runtime with the wallpaper).
- Dynamic wallpaper-derived colour; per-theme options layered over global settings.
- Text via `Txt`, glyphs via `Icon` + `Icons` names. Bar modules compact; details in popouts. Everything reacts to hover. Short subtle animations.
- Handle every empty state with a calm one-line placeholder.

## Working rules (the user is often in a fullscreen game)

- Never run plain `qs` or open windows on their main screen; never change system state in tests (volume, network, dispatches, notifications, docker, killing processes). Never `pkill -f` a pattern that also appears in your own command line.
- Lint: `qmllint -I /usr/lib/qt6/qml <file>` — unresolved `qs.*` import warnings are expected, errors are not.
- Headless probe: a `ShellRoot` with **no windows** in the shell root dir (so `qs.*` imports work), `console.log("PROBE", ...)`, `Timer { interval: 5000; running: true; onTriggered: Qt.quit() }`, run `timeout 10 qs -p <dir>/probe_x.qml 2>&1 | grep -a PROBE`, then delete it. Use `Variants { model: [...] }` (not `Repeater`) for non-visual repeated objects like `ColorQuantizer`.
- Visual test as a second instance on the secondary monitor only: `QS_TEST_SCREEN=HDMI-A-2 qs -p ~/shell-work/shell`, screenshot only HDMI-A-2 (`grim -o HDMI-A-2`), then stop that instance by PID.
- No sudo — package installs must be asked of the user. Not installed: matugen, brightnessctl, rofi/fuzzel, hyprlock. (cliphist, pavucontrol, playerctl, satty, hyprpicker installed 2026-11-10.)

## Gotchas

- `Behavior` directly inside a `Singleton` segfaults Quickshell on this build (Theme.qml cross-fades colours manually for this reason).
- Hyprland raw dispatch takes Lua: `Hyprland.dispatch("hl.dsp.focus({ workspace = 3 })")`.
- Pipewire volume needs `PwObjectTracker`; UntypedObjectModels are used as `model:` or via `.values`.
- More in SPEC.md → Gotchas.

## Delegation

For multi-part shell work the user prefers parallel **Sonnet** subagents with tight briefs (no need for Opus/Fable). Give each: SPEC.md path, its exact files (one feature area each — see the table in `~/shell-work/README.md`), work in `~/shell-work/shell/`, and the report format at the end of SPEC.md. The orchestrator copies results into `~/.config/quickshell/` and does visual testing.

Still deferred (risky, ask first): lock screen + idle, polkit agent swap, greeter. (GTK recolouring done 2026-11-10; Qt apps use Kvantum WhiteSur, not tinted.)
