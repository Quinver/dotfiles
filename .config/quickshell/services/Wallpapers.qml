pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../config/Palette.js" as Palette

// Wallpaper list of the active theme, the current image, rotation and the
// colour seed extracted from it.
Singleton {
	id: root

	property var files: []                 // absolute paths, sorted
	property int index: 0
	readonly property string current: files.length ? files[Math.max(0, Math.min(index, files.length - 1))] : ""
	readonly property string dir: Settings.expand(Settings.theme.wallpapers || "")
	readonly property var colorCfg: Settings.theme.colors || ({})
	readonly property string colorSource: colorCfg.source || "wallpaper"   // wallpaper | seed | mono
	readonly property bool rotating: Settings.opt("rotate", true) && !Settings.state.rotatePaused && files.length > 1
	readonly property int interval: Math.max(5, Settings.opt("rotateInterval", 600))
	property string extracted: ""
	// Hex colour every palette is generated from.
	readonly property string seed: colorSource === "wallpaper"
		? (extracted || "#6b7f8c")
		: (colorCfg.seed || "#808080")
	property bool loaded: false

	function url(path) { return path ? "file://" + path : ""; }

	function set(path) {
		var i = files.indexOf(path);
		if (i === -1) return;
		index = i;
		_remember();
		rotation.restart();
	}

	function next() {
		if (!files.length) return;
		if (Settings.opt("rotateOrder", "sequential") === "random" && files.length > 2) {
			var n = index;
			while (n === index) n = Math.floor(Math.random() * files.length);
			index = n;
		} else {
			index = (index + 1) % files.length;
		}
		_remember();
		rotation.restart();
	}

	function prev() {
		if (!files.length) return;
		index = (index - 1 + files.length) % files.length;
		_remember();
		rotation.restart();
	}

	function togglePause() { Settings.setState("rotatePaused", !Settings.state.rotatePaused); }

	function _remember() {
		var m = Object.assign({}, Settings.state.wallpapers || {});
		m[Settings.themeName] = current;
		Settings.setState("wallpapers", m);
	}

	function refresh() {
		if (!Settings.ready || dir === "") return;
		lister.command = ["sh", "-c",
			"find -L \"$1\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.svg' \\) | sort",
			"sh", dir];
		lister.running = true;
	}

	onDirChanged: refresh()
	Connections {
		target: Settings
		function onReadyChanged() { root.refresh(); }
	}
	Component.onCompleted: refresh()

	Process {
		id: lister
		stdout: StdioCollector {
			onStreamFinished: {
				var list = text.split("\n").filter(l => l.length > 0);
				var saved = (Settings.state.wallpapers || {})[Settings.themeName];
				var i = list.indexOf(saved);
				root.files = list;
				root.index = i === -1 ? 0 : i;
				root.loaded = true;
			}
		}
	}

	Timer {
		id: rotation
		interval: root.interval * 1000
		repeat: true
		running: root.rotating
		onTriggered: root.next()
	}

	ColorQuantizer {
		id: quant
		source: root.colorSource === "wallpaper" ? root.url(root.current) : ""
		depth: 4
		rescaleSize: 96
		onColorsChanged: {
			if (!colors.length) return;
			root.extracted = Palette.pickSeed(colors.map(c => c.toString()));
		}
	}
}
