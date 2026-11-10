pragma Singleton
import QtQuick
import Quickshell
import qs.services
import "Palette.js" as Palette

// Resolved design tokens. Every visual value in the shell comes from here, so
// switching theme / wallpaper restyles everything at once.
Singleton {
	id: root

	readonly property var colorCfg: Settings.theme.colors || ({})
	readonly property bool mono: colorCfg.source === "mono"
	readonly property var pal: Palette.generate(Wallpapers.seed, {
		mode: Settings.opt("mode", "dark"),
		mono: root.mono,
		chroma: Settings.opt("chroma", 1.0),
		overrides: Settings.theme.palette
	})
	readonly property int colorAnim: 700

	// ---- colours ----
	// Palette changes cross-fade: every colour is a blend of the previous and
	// the new palette, driven by one animated number. (Behavior objects inside
	// a Quickshell Singleton segfault on this build, hence this approach.)
	property var palFrom: pal
	property var palTo: pal
	property real blend: 1
	onPalChanged: {
		var snap = {};
		for (var k in palTo) snap[k] = (k === "seed" || k === "mode") ? palTo[k] : Palette.mix(palFrom[k], palTo[k], blend);
		palFrom = snap;
		blend = 0;
		palTo = pal;
		fade.restart();
	}
	NumberAnimation { id: fade; target: root; property: "blend"; from: 0; to: 1; duration: root.colorAnim; easing.type: Easing.InOutQuad }
	function role(k) { return Palette.mix(palFrom[k], palTo[k], blend); }

	readonly property color bg: role("bg")   // bar / window background
	readonly property color surface: role("surface")   // popouts, cards
	readonly property color surfaceHi: role("surfaceHi")   // hover
	readonly property color surfaceTop: role("surfaceTop")   // pressed / selected
	readonly property color outline: role("outline")   // borders
	readonly property color outlineDim: role("outlineDim")   // separators
	readonly property color fg: role("fg")   // text
	readonly property color fgDim: role("fgDim")   // secondary text
	readonly property color fgMuted: role("fgMuted")   // disabled / hints
	readonly property color primary: role("primary")   // accent
	readonly property color onPrimary: role("onPrimary")   // text on accent
	readonly property color primaryDim: role("primaryDim")   // accent container
	readonly property color secondary: role("secondary")
	readonly property color tertiary: role("tertiary")
	readonly property color error: role("error")
	readonly property color warn: role("warn")
	readonly property color ok: role("ok")
	readonly property color shadow: pal.shadow

	// ---- shape ----
	readonly property int rounding: Settings.opt("rounding", 0)             // big surfaces
	readonly property int roundingSmall: Math.min(rounding, Math.round(rounding * 0.5)) // buttons, inputs
	readonly property int border: Settings.opt("border", 1)

	// ---- metrics ----
	readonly property int barHeight: Settings.opt("barHeight", 32)
	readonly property real barOpacity: Settings.opt("barOpacity", 1.0)
	readonly property real panelOpacity: Settings.opt("panelOpacity", 1.0)
	readonly property int gap: Settings.opt("gap", 8)       // distance between surfaces / screen edge
	readonly property int pad: Settings.opt("pad", 10)      // padding inside surfaces
	readonly property int spacing: Math.round(pad * 0.6)    // between sibling controls
	readonly property int popoutWidth: 360
	readonly property int rowHeight: 34                     // list rows, buttons

	// ---- type ----
	readonly property string font: Settings.opt("font", "Adwaita Sans")
	readonly property string monoFont: Settings.opt("monoFont", "JetBrainsMono Nerd Font")
	readonly property string iconFont: "JetBrainsMono Nerd Font"
	readonly property int fontSize: Settings.opt("fontSize", 12)
	readonly property int fontSmall: fontSize - 2
	readonly property int fontLarge: fontSize + 3
	readonly property int fontHuge: fontSize + 14
	readonly property int iconSize: fontSize + 3

	// ---- motion ----
	readonly property real animSpeed: Math.max(0.01, Settings.opt("animSpeed", 1.0))
	readonly property int animFast: Math.round(110 / animSpeed)
	readonly property int anim: Math.round(200 / animSpeed)
	readonly property int animSlow: Math.round(450 / animSpeed)

	function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
}
