pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history backed by cliphist.
//
//   Clipboard.entries     [{ line, preview, isImage }] newest first, max 100 (REPLACED on refresh)
//   Clipboard.refresh()   reload from `cliphist list` (the panel calls it when opened)
//   Clipboard.copy(line)  put an entry back on the clipboard
//   Clipboard.remove(line) / wipe()
//
// `line` is the raw cliphist list line and is what cliphist decode/delete expect.
Singleton {
	id: root

	readonly property int maxEntries: 100
	property var entries: []

	function refresh() { if (!lister.running) lister.running = true; }
	function copy(line) { _run(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "_", line]); }
	function remove(line) {
		root.entries = root.entries.filter(e => e.line !== line);
		_run(["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "_", line]);
	}
	function wipe() {
		root.entries = [];
		_run(["cliphist", "wipe"]);
	}

	function _run(cmd) { Quickshell.execDetached(cmd); }

	Process {
		id: lister
		command: ["cliphist", "list"]
		stdout: StdioCollector {
			onStreamFinished: {
				var out = [];
				var lines = text.split("\n");
				for (var i = 0; i < lines.length && out.length < root.maxEntries; i++) {
					var l = lines[i];
					var tab = l.indexOf("\t");
					if (tab < 0) continue;
					var p = l.substring(tab + 1);
					out.push({ line: l, preview: p, isImage: /^\[\[ binary data .*(png|jpe?g|bmp|webp|gif)/i.test(p) });
				}
				root.entries = out;
			}
		}
	}
}
