pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Local llama.cpp server (docker container) status + controls.
// state: "off" | "connecting" | "up" | "unhealthy". `available` is false when
// docker or the toggle script is missing. toggle() runs the user's script,
// restart() does `docker compose restart`. Never called from tests.
Singleton {
	id: root

	readonly property string container: Settings.opt("llmContainer", "qwen-llamacpp")
	readonly property string script: Settings.expand(Settings.opt("llmToggle", "~/local-llm/main/toggle-llama.sh"))
	property string state: "off"
	property bool available: false
	property int _fast: 0           // fast polls left after a toggle/restart

	function toggle() { Quickshell.execDetached([script]); _kick(); }

	function restart() {
		Quickshell.execDetached(["sh", "-c", "cd \"$(dirname \"$1\")\" && docker compose restart", "sh", script]);
		_kick();
	}

	function _kick() { _fast = 5; poll.interval = 3000; poll.restart(); }

	Process {
		running: true
		command: ["sh", "-c", "command -v docker >/dev/null && test -f \"$1\"", "sh", root.script]
		onExited: code => { root.available = code === 0; }
	}

	Process {
		id: probe
		command: ["sh", "-c",
			"if [ -n \"$(docker ps -q --filter name=^$1\\$ --filter status=running 2>/dev/null)\" ]; then "
			+ "docker inspect --format '{{.State.Health.Status}}' \"$1\" 2>/dev/null || echo healthy; else echo off; fi",
			"sh", root.container]
		stdout: StdioCollector {
			onStreamFinished: {
				var s = text.trim();
				root.state = s === "off" ? "off" : s === "starting" ? "connecting" : s === "unhealthy" ? "unhealthy" : "up";
				if (root._fast > 0) root._fast--;
				poll.interval = root.state === "connecting" || root._fast > 0 ? 2500 : 10000;
			}
		}
	}

	Timer {
		id: poll
		interval: 10000
		repeat: true
		running: root.available
		triggeredOnStart: true
		onTriggered: if (!probe.running) probe.running = true
	}
}
