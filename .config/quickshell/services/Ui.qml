pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services

// Which popout / overlay is open, and where.
//
//   Ui.toggle("audio", barItem)   popout under a bar item
//   Ui.toggle("audio")            popout on the focused monitor (keybinds / IPC)
//   Ui.toggleOverlay("launcher")  full-screen overlay (launcher, power, ...)
//   Ui.close()
// Features backed by an optional tool refuse to open while unavailable(name) is true.
Singleton {
	id: root

	property string popout: ""       // name of the open popout, "" = none
	property var screen: null        // ShellScreen it is open on
	property real anchorX: -1        // x (screen coords) the popout centres on; -1 = right edge
	property string overlay: ""      // name of the open overlay, "" = none
	property var overlayScreen: null
	property var bars: []            // bar windows, so clicks on the bar do not dismiss popouts
	property var buttons: []         // BarButtons with a popout, so keybinds open under the matching button

	// Test mode (QS_TEST_SCREEN=HDMI-A-2 qs ...): everything opens on that
	// monitor and nothing ever takes keyboard focus, so the shell can be
	// exercised while the session is in use.
	readonly property string testScreen: Quickshell.env("QS_TEST_SCREEN") || ""
	readonly property bool testMode: testScreen !== ""

	function focusedScreen() {
		if (testMode) {
			var all = Quickshell.screens;
			for (var j = 0; j < all.length; j++) if (all[j].name === testScreen) return all[j];
		}
		var m = Hyprland.focusedMonitor;
		var list = Quickshell.screens;
		if (m) for (var i = 0; i < list.length; i++) if (list[i].name === m.name) return list[i];
		return list.length ? list[0] : null;
	}

	function screenOf(item) {
		if (item && item.QsWindow && item.QsWindow.window) return item.QsWindow.window.screen;
		return focusedScreen();
	}

	// The bar button for `name` on screen `s`, if that monitor's bar shows one.
	function buttonFor(name, s) {
		for (var i = 0; i < buttons.length; i++) {
			var b = buttons[i];
			if (b.popout === name && b.visible && screenOf(b) === s) return b;
		}
		return null;
	}

	// False for popouts / overlays whose external tools are missing.
	function usable(name) {
		switch (name) {
		case "ai": return Llm.available || AiUsage.available;
		case "network": return Net.available;
		case "clipboard": return Clipboard.available;
		case "docker": return Containers.available;
		case "games": return Games.available;
		case "capture": return Capture.available;
		case "tasks": return Deps.has("python3");
		case "keys": return Deps.exists(Keybinds.path);
		default: return true;
		}
	}

	function open(name, item) {
		if (!usable(name)) return;
		var s = screenOf(item);
		if (!item) item = buttonFor(name, s);
		overlay = "";
		anchorX = item ? item.mapToItem(null, item.width / 2, 0).x : -1;
		screen = s;
		popout = name;
	}

	function toggle(name, item) {
		if (!usable(name)) return;
		var s = screenOf(item);
		if (popout === name && screen === s) close();
		else open(name, item);
	}

	function isOpen(name, item) { return popout === name && screen === screenOf(item); }

	function toggleOverlay(name) {
		if (!usable(name)) return;
		if (overlay === name) { overlay = ""; return; }
		popout = "";
		overlayScreen = focusedScreen();
		overlay = name;
	}

	function close() { popout = ""; overlay = ""; }

	function registerButton(b) { buttons = buttons.concat([b]); }
	function unregisterButton(b) { buttons = buttons.filter(x => x !== b); }

	function registerBar(w) { bars = bars.concat([w]); }
	function unregisterBar(w) { bars = bars.filter(b => b !== w); }
}
