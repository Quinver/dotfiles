pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// Shared Hyprland window/workspace data. Keeps Hyprland.toplevels fresh from raw
// events and offers helpers for the workspaces bar, taskbar and windows panel.
// Bindings that call the helpers re-evaluate when `rev` changes (after a refresh).
Singleton {
	id: root

	property int rev: 0
	// { monitorName: [workspace ids] } from `hyprctl -j workspacerules`
	property var rules: ({})

	readonly property var refreshEvents: [
		"openwindow", "closewindow", "movewindow", "movewindowv2", "windowtitle", "windowtitlev2",
		"changefloatingmode", "fullscreen", "urgent", "activewindowv2", "workspace", "workspacev2",
		"focusedmon", "createworkspace", "destroyworkspace", "moveworkspace"
	]

	function classOf(toplevel) {
		if (!toplevel) return "";
		var c = toplevel.lastIpcObject ? toplevel.lastIpcObject.class : "";
		if (c) return c;
		return toplevel.wayland && toplevel.wayland.appId ? toplevel.wayland.appId : "";
	}

	function windowsOn(workspaceId) {
		void rev;
		var list = Hyprland.toplevels.values.filter(t => t.workspace && t.workspace.id === workspaceId);
		function at(t, i) { var a = t.lastIpcObject ? t.lastIpcObject.at : null; return a ? a[i] : 0; }
		list.sort((a, b) => (at(a, 0) - at(b, 0)) || (at(a, 1) - at(b, 1)) || (a.address < b.address ? -1 : 1));
		return list;
	}

	function monitorFor(screen) {
		return Hyprland.monitorFor(screen);
	}

	function persistentFor(monitorName) {
		var ids = rules[monitorName];
		if (ids) return ids;
		if (Object.keys(rules).length > 0) return [];
		var n = Settings.opt("workspaces", 5);
		var out = [];
		for (var i = 1; i <= n; i++) out.push(i);
		return out;
	}

	function parseRules(text) {
		var out = {};
		try {
			JSON.parse(text).forEach(r => {
				var id = parseInt(r.workspaceString);
				if (!r.monitor || isNaN(id) || r.enabled === false) return;
				(out[r.monitor] = out[r.monitor] || []).push(id);
			});
		} catch (e) {}
		for (var m in out) out[m].sort((a, b) => a - b);
		rules = out;
	}

	Process {
		running: true
		command: ["hyprctl", "-j", "workspacerules"]
		stdout: StdioCollector { onStreamFinished: root.parseRules(text) }
	}

	Timer {
		id: debounce
		interval: 80
		onTriggered: {
			Hyprland.refreshToplevels();
			Hyprland.refreshWorkspaces();
			root.rev++;
		}
	}

	Connections {
		target: Hyprland
		function onRawEvent(event) {
			if (root.refreshEvents.indexOf(event.name) >= 0) debounce.restart();
		}
	}
}
