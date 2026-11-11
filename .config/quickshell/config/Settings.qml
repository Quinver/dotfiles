pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// User configuration (settings.json, hand-editable, live-reloaded) and
// runtime state (state.json, written by the shell).
//
//   Settings.opt("rounding", 0)   -> current theme's option, else global, else fallback
//   Settings.setTheme("safe")     -> switch theme
//   Settings.setOption(k, v)      -> change a GLOBAL option (persisted)
//   Settings.setThemeOption(k, v, name) -> change an option for a theme (default: current)
//   Settings.state.x / Settings.setState("x", v)
Singleton {
	id: root

	readonly property string home: Quickshell.env("HOME")
	readonly property string settingsPath: Quickshell.shellDir + "/settings.json"

	property var data: ({})
	property var state: ({})
	property bool settingsLoaded: false
	property bool stateLoaded: false
	readonly property bool ready: settingsLoaded && stateLoaded

	// Every global option with its default. A theme may override any of these
	// in its own "options" block.
	readonly property var defaults: ({
		font: "Adwaita Sans",
		monoFont: "JetBrainsMono Nerd Font",
		fontSize: 12,
		barHeight: 32,
		barOpacity: 1.0,
		panelOpacity: 1.0,
		rounding: 0,
		border: 1,
		gap: 8,
		pad: 10,
		animSpeed: 1.0,
		mode: "dark",
		chroma: 1.0,
		rotate: true,
		rotateInterval: 600,
		rotateOrder: "sequential",
		startupTheme: "last",
		safeTheme: "safe",
		clockFormat: "HH:mm",
		dateFormat: "ddd d MMM",
		workspaces: 5,
		applyHyprland: true,
		hyprBorder: 2,
		applyAlacritty: true,
		terminal: "alacritty",
		notifyTimeout: 6,
		llmContainer: "qwen-llamacpp",
		llmToggle: "~/local-llm/main/toggle-llama.sh",
		lockCommand: "",
		iconStyle: "tinted",
		barLeft: ["Burger", "Workspaces", "Taskbar"],
		barCenter: ["Clock"],
		barRight: ["Media", "Llm", "System", "Network", "Bluetooth", "Audio", "Tray", "Notifs"]
	})

	readonly property var global: Object.assign({}, defaults, data.global || {})
	readonly property var themes: data.themes || ({})
	readonly property var themeNames: Object.keys(themes)
	// Persisted theme, and the effective one: a transient in-memory preview
	// (Theme Studio) wins while set. Everything restyles from themeName.
	property string previewTheme: ""
	readonly property bool previewing: previewTheme !== "" && themes[previewTheme] !== undefined && previewTheme !== savedThemeName
	readonly property string savedThemeName: {
		if (state.theme && themes[state.theme]) return state.theme;
		return themeNames.length ? themeNames[0] : "";
	}
	readonly property string themeName: previewing ? previewTheme : savedThemeName
	readonly property var theme: themes[themeName] || ({})
	readonly property bool safeActive: themeName === global.safeTheme

	function opt(key, fallback) {
		var o = theme.options;
		if (o && o[key] !== undefined) return o[key];
		if (global[key] !== undefined) return global[key];
		return fallback;
	}

	// "~/x" -> "/home/me/x"; relative paths are relative to the shell directory.
	function expand(p) {
		if (!p) return "";
		if (p.indexOf("~/") === 0) return home + p.substring(1);
		if (p.charAt(0) === "/") return p;
		return Quickshell.shellDir + "/" + p;
	}

	function themeLabel(name) {
		var t = themes[name];
		return t && t.label ? t.label : name;
	}

	function setTheme(name) {
		if (!themes[name] || name === savedThemeName) return;
		var s = Object.assign({}, state);
		s.prevTheme = savedThemeName;
		s.theme = name;
		_writeState(s);
	}

	function nextTheme() {
		var i = themeNames.indexOf(savedThemeName);
		if (themeNames.length) setTheme(themeNames[(i + 1) % themeNames.length]);
	}

	// Jump to the safe theme, or back to whatever was active before.
	function toggleSafe() {
		var safe = global.safeTheme;
		if (!themes[safe]) return;
		if (savedThemeName === safe) {
			var back = state.prevTheme;
			if (!back || !themes[back] || back === safe)
				back = themeNames.filter(n => n !== safe)[0];
			if (back) setTheme(back);
		} else {
			setTheme(safe);
		}
	}

	function setState(key, value) {
		var s = Object.assign({}, state);
		s[key] = value;
		_writeState(s);
	}

	function setOption(key, value) {
		var d = JSON.parse(JSON.stringify(data));
		if (!d.global) d.global = {};
		d.global[key] = value;
		_writeSettings(d);
	}

	// Set (or, with null, remove) an option override on theme `name` (default: current).
	function setThemeOption(key, value, name) {
		var n = name || themeName;
		var d = JSON.parse(JSON.stringify(data));
		if (!d.themes || !d.themes[n]) return;
		if (!d.themes[n].options) d.themes[n].options = {};
		if (value === undefined || value === null) delete d.themes[n].options[key];
		else d.themes[n].options[key] = value;
		_writeSettings(d);
	}

	// A theme's own override of `key`, or undefined when it inherits.
	function themeOptionRaw(name, key) {
		var t = themes[name];
		return t && t.options ? t.options[key] : undefined;
	}

	function globalValue(key) {
		var v = global[key];
		return v !== undefined && v !== null ? v : defaults[key];
	}

	function _writeState(s) {
		root.state = s;
		stateFile.setText(JSON.stringify(s, null, "\t") + "\n");
	}

	function _writeSettings(d) {
		root.data = d;
		settingsFile.setText(JSON.stringify(d, null, "\t") + "\n");
	}

	function _parse(text, what) {
		try {
			return JSON.parse(text);
		} catch (e) {
			console.warn("Settings: could not parse " + what + ": " + e);
			return null;
		}
	}

	function _applyStartupTheme() {
		var want = global.startupTheme;
		if (want && want !== "last" && themes[want] && state.theme !== want) setTheme(want);
	}

	FileView {
		id: settingsFile
		path: root.settingsPath
		watchChanges: true
		onFileChanged: reload()
		onLoaded: {
			var d = root._parse(text(), "settings.json");
			if (d) root.data = d;
			var first = !root.settingsLoaded;
			root.settingsLoaded = true;
			if (first && root.stateLoaded) root._applyStartupTheme();
		}
		onLoadFailed: root.settingsLoaded = true
	}

	FileView {
		id: stateFile
		path: Quickshell.statePath("state.json")
		printErrors: false
		onLoaded: {
			var s = root._parse(text(), "state.json");
			if (s) root.state = s;
			var first = !root.stateLoaded;
			root.stateLoaded = true;
			if (first && root.settingsLoaded) root._applyStartupTheme();
		}
		onLoadFailed: {
			var first = !root.stateLoaded;
			root.stateLoaded = true;
			if (first && root.settingsLoaded) root._applyStartupTheme();
		}
	}
}
