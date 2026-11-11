pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Installed games (Steam, Faugus, Prism) and Steam accounts for the games
// overlay. Data comes from scripts/games.py; the overlay calls refresh() when it
// opens. launch() starts a game detached, switchAccount() restarts Steam.
Singleton {
	id: root

	property var accounts: []
	property var games: []
	property bool loading: false
	property bool loaded: false
	readonly property bool available: Deps.has("python3")
		&& (Deps.has("steam") || Deps.has("faugus-launcher") || Deps.has("prismlauncher"))
	readonly property string script: Quickshell.shellDir + "/scripts/games.py"

	function refresh() {
		if (!available || listProc.running) return;
		loading = true;
		listProc.running = true;
	}

	function launch(game) {
		if (game && game.launch && game.launch.length > 0) Quickshell.execDetached(game.launch);
	}

	// Rewrites Steam's login files and restarts Steam as that account.
	function switchAccount(name) {
		if (name === "") return;
		Quickshell.execDetached(["python3", script, "switch", name]);
	}

	Process {
		id: listProc
		command: ["python3", root.script, "list"]
		stdout: StdioCollector {
			onStreamFinished: {
				try {
					var d = JSON.parse(text);
					root.accounts = d.accounts || [];
					root.games = d.games || [];
					root.loaded = true;
				} catch (e) { console.warn("Games: bad output"); }
				root.loading = false;
			}
		}
		onExited: root.loading = false
	}
}
