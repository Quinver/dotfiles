pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Claude Code and opencode usage for the AI panel. Data comes from
// scripts/ai_usage.py; it is only collected while the panel is open
// (the panel calls refresh() and keeps `watchers` > 0).
Singleton {
	id: root

	property var info: ({})
	property bool loading: false
	property int watchers: 0
	readonly property var claude: info.claude || ({})
	readonly property var opencode: info.opencode || ({})

	function refresh() {
		if (proc.running) return;
		loading = true;
		proc.running = true;
	}

	// 1234 -> "1.2k", 1500000 -> "1.5M"
	function fmt(n) {
		n = Number(n) || 0;
		if (n >= 1e9) return (n / 1e9).toFixed(2) + "B";
		if (n >= 1e6) return (n / 1e6).toFixed(1) + "M";
		if (n >= 1e3) return (n / 1e3).toFixed(1) + "k";
		return String(Math.round(n));
	}

	Timer {
		interval: 60000
		repeat: true
		running: root.watchers > 0
		onTriggered: root.refresh()
	}

	Process {
		id: proc
		command: ["python3", Quickshell.shellDir + "/scripts/ai_usage.py"]
		stdout: StdioCollector {
			onStreamFinished: {
				try { root.info = JSON.parse(text); } catch (e) { console.warn("AiUsage: bad output"); }
				root.loading = false;
			}
		}
		onExited: root.loading = false
	}
}
