pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Screenshot + screen-recording service. Lives here (not in the overlay) so
// the processes outlive the overlay and the recording state is shared.
//   Capture.shot("region"|"window"|"screen"|"all", "copy"|"save"|"edit")
//   Capture.startRecord("region"|"screen", audio) / stopRecord() / toggleRecord()
// Last choices (mode/action/audio) are kept here for the session.
Singleton {
	id: root

	property string mode: "region"
	property string action: "copy"
	property bool audio: false

	property bool recording: false
	property int elapsed: 0
	property string lastFile: ""
	property string recScreen: ""        // monitor the recording started on (indicator shows there)

	readonly property string img: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-capture.png"

	// ---- screenshots -------------------------------------------------------
	property string pendingCmd: ""

	function shotCommand(mode, action, monitor) {
		var q = "'" + monitor + "'";
		var s = 'IMG="' + img + '"; D="$HOME/Pictures/Screenshots"; F="$D/shot_$(date +%Y-%m-%d_%H-%M-%S).png"; FZ=""\n';
		var freeze = 'if command -v wayfreeze >/dev/null 2>&1; then wayfreeze & FZ=$!; sleep .1; fi\n'
			+ 'unfreeze() { [ -n "$FZ" ] && kill "$FZ" 2>/dev/null; }\n';
		if (mode === "region") {
			s += freeze + 'G=$(slurp) || { unfreeze; exit 0; }\ngrim -g "$G" "$IMG"; unfreeze\n';
		} else if (mode === "window") {
			s += freeze + 'G=$(hyprctl -j clients | jq -r --argjson ws "$(hyprctl -j monitors | jq -c \'[.[].activeWorkspace.id]\')" '
				+ '\'.[] | select(.mapped and (.hidden | not) and (.workspace.id as $i | $ws | index($i))) | "\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])"\' '
				+ '| slurp -r) || { unfreeze; exit 0; }\ngrim -g "$G" "$IMG"; unfreeze\n';
		} else if (mode === "screen") {
			s += 'grim -o ' + q + ' "$IMG" || exit 1\n';
		} else {
			s += 'grim "$IMG" || exit 1\n';
		}
		if (action === "copy") {
			s += 'wl-copy -t image/png < "$IMG" && notify-send -a Screenshot -i "$IMG" "Screenshot copied" "Copied to clipboard"\n';
		} else if (action === "save") {
			s += 'mkdir -p "$D" && cp "$IMG" "$F" && notify-send -a Screenshot -i "$F" "Screenshot saved" "$F"\n';
		} else {
			s += 'mkdir -p "$D"; satty --filename "$IMG" --output-filename "$F" --copy-command wl-copy --early-exit\n';
		}
		return s;
	}

	function shot(mode, action) {
		if (["region", "window", "screen", "all"].indexOf(mode) < 0) return;
		if (["copy", "save", "edit"].indexOf(action) < 0) return;
		root.mode = mode;
		root.action = action;
		var mon = Ui.overlayScreen ? Ui.overlayScreen.name : (Ui.focusedScreen() ? Ui.focusedScreen().name : "");
		pendingCmd = shotCommand(mode, action, mon);
		Ui.close();
		delay.restart();
	}

	Timer {
		id: delay
		interval: 250
		onTriggered: Quickshell.execDetached(["sh", "-c", root.pendingCmd])
	}

	// ---- recording ---------------------------------------------------------
	property string recCmd: ""

	function recordCommand(mode, audio, monitor, geo) {
		var s = 'D="$HOME/Videos/Recordings"; mkdir -p "$D"; F="$D/rec_$(date +%Y-%m-%d_%H-%M-%S).mp4"\n'
			+ 'echo "$F" > "$XDG_RUNTIME_DIR/qs-capture-file"\n';
		var args = '-f "$F"';
		if (mode === "region") args += " -g '" + geo + "'";
		else args += " -o '" + monitor + "'";
		if (audio) {
			s += 'A=$(pactl get-default-sink).monitor\n';
			args += ' --audio="$A"';
		}
		return s + "exec wf-recorder " + args + "\n";
	}

	function startRecord(mode, audio) {
		if (recording || recProc.running || geoProc.running) return;
		if (mode !== "region" && mode !== "screen") return;
		root.mode = mode;
		root.audio = audio;
		var mon = Ui.overlayScreen ? Ui.overlayScreen.name : (Ui.focusedScreen() ? Ui.focusedScreen().name : "");
		recScreen = mon;
		recMode = mode;
		recCmd = recordCommand(mode, audio, mon, "");
		Ui.close();
		recDelay.restart();
	}

	property string recMode: ""

	Timer {
		id: recDelay
		interval: 250
		onTriggered: {
			if (root.recMode === "region") {
				geoProc.running = true;
			} else {
				root.beginRecording(root.recCmd);
			}
		}
	}

	function beginRecording(cmd) {
		root.elapsed = 0;
		recProc.command = ["sh", "-c", cmd];
		recProc.running = true;
	}

	// Step 1 (region only): select the area under wayfreeze. Prints the
	// geometry only when slurp succeeds, so a cancel produces no output.
	Process {
		id: geoProc
		command: ["sh", "-c",
			'if command -v wayfreeze >/dev/null 2>&1; then wayfreeze & FZ=$!; sleep .1; fi; '
			+ 'G=$(slurp); R=$?; [ -n "$FZ" ] && kill "$FZ" 2>/dev/null; [ $R -eq 0 ] && printf "%s" "$G"']
		stdout: StdioCollector {
			onStreamFinished: {
				var g = text.trim();
				if (g !== "" && /^[0-9,. x+-]+$/.test(g))
					root.beginRecording(root.recordCommand("region", root.audio, root.recScreen, g));
			}
		}
	}

	function stopRecord() {
		if (recProc.running) recProc.signal(2);   // SIGINT: wf-recorder finalises the file
	}

	function toggleRecord() {
		if (recording) stopRecord();
		else startRecord(mode === "screen" ? "screen" : "region", audio);
	}

	Process {
		id: recProc
		onStarted: root.recording = true
		onExited: function (code) {
			var was = root.recording;
			root.recording = false;
			fileRead.reload();
			if (was) finishNote.restart();
		}
	}

	// Slurp cancelled -> process exits without ever having recorded; the file
	// marker is only trusted when a recording really ran for > 0 s.
	FileView {
		id: fileRead
		preload: false
		path: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-capture-file"
		onLoaded: root.lastFile = text().trim()
	}

	Timer {
		id: finishNote
		interval: 150
		onTriggered: {
			if (root.lastFile !== "" && root.elapsed >= 1)
				Quickshell.execDetached(["notify-send", "-a", "Screenshot", "Recording saved", root.lastFile]);
		}
	}

	Timer {
		interval: 1000
		repeat: true
		running: root.recording
		onTriggered: root.elapsed++
	}

	function fmt(sec) {
		var m = Math.floor(sec / 60), s = sec % 60;
		return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
	}
}
