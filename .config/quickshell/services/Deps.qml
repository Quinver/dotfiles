pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// Which optional external tools and files exist on this machine. One shell
// Process at startup probes everything; services build their `available`
// flags on it so a feature whose tool is missing hides instead of failing.
//
//   Deps.has("docker")        binary on PATH (false until `ready`)
//   Deps.exists("/some/file") one of the probed files (see `files`)
//   Deps.ready                the probe finished
// Both functions read `found`, so bindings re-evaluate when the probe returns.
Singleton {
	id: root

	readonly property var commands: [
		"docker", "ssh", "virsh", "cliphist", "wl-copy", "grim", "slurp", "satty", "wf-recorder",
		"steam", "faugus-launcher", "prismlauncher", "nmcli", "speedtest", "fcitx5-remote",
		"python3", "opencode", "nm-connection-editor"
	]
	readonly property var files: [
		Settings.expand(Settings.opt("llmToggle", "~/projects/local-llm/main/toggle-llama.sh")),
		Settings.home + "/.claude/.credentials.json",
		Keybinds.path
	]

	property var found: []
	property bool ready: false

	function has(name) { return found.indexOf("c:" + name) >= 0; }
	function exists(path) { return found.indexOf("f:" + path) >= 0; }

	Process {
		running: true
		command: ["sh", "-c",
			"for c in $1; do command -v \"$c\" >/dev/null 2>&1 && echo \"c:$c\"; done; shift; "
			+ "for f in \"$@\"; do [ -e \"$f\" ] && echo \"f:$f\"; done; true",
			"sh", root.commands.join(" ")].concat(root.files)
		stdout: StdioCollector {
			onStreamFinished: {
				root.found = text.split("\n").filter(l => l !== "");
				root.ready = true;
			}
		}
	}
}
