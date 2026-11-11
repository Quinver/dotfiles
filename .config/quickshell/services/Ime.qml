pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// fcitx5 input method state. fcitx5 emits no DBus signal on IM switch (only
// InputMethodGroupsChanged) and registers no tray item, so we poll
// `fcitx5-remote -n` every 700ms (cheap) and refresh right after our own actions.
Singleton {
	id: root

	property string name: ""          // last known IM; kept while no window has an input context
	property bool available: false    // fcitx5 reachable
	readonly property bool japanese: name === "mozc" || name.indexOf("mozc") === 0 || name.indexOf("anthy") === 0 || name.indexOf("kkc") === 0

	function refresh() { if (!query.running) query.running = true; }
	function toggle() { Quickshell.execDetached(["fcitx5-remote", "-t"]); settle.restart(); }
	function set(imName) { Quickshell.execDetached(["fcitx5-remote", "-s", imName]); settle.restart(); }
	function openConfig() { Quickshell.execDetached(["fcitx5-configtool"]); }

	Process {
		id: query
		// prints the IM name, or nothing when no input context is focused (e.g. a game)
		command: ["sh", "-c", "fcitx5-remote >/dev/null 2>&1 || exit 1; fcitx5-remote -n"]
		stdout: StdioCollector { onStreamFinished: { const n = text.trim(); if (n !== "") root.name = n; } }
		onExited: code => { root.available = code === 0; }
	}
	Timer { interval: 700; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
	Timer { id: settle; interval: 80; onTriggered: root.refresh() }
}
