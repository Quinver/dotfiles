pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Canvas LMS deadlines + announcements (scripts/canvas.py). Inert unless a token is configured.
Singleton {
	id: root

	property bool configured: false
	readonly property bool available: configured
	property var deadlines: []
	property var announcements: []
	property bool loading: false
	property string error: ""
	property string fetched: ""
	property var now: new Date()

	readonly property real soonHours: Number(Settings.opt("canvasSoonHours", 48))
	readonly property int dueSoonCount: {
		const t = now.getTime(), lim = t + soonHours * 3600000;
		return deadlines.filter(d => {
			const x = new Date(d.due).getTime();
			return !d.submitted && x >= t && x <= lim;
		}).length;
	}
	readonly property bool dueToday: deadlines.some(d => {
		const x = new Date(d.due).getTime();
		return !d.submitted && x >= now.getTime() && x <= now.getTime() + 86400000;
	})
	readonly property int newAnnouncements: announcements.filter(a => !a.read).length

	readonly property string cachePath: Settings.home + "/.cache/qshell/canvas.json"

	function refresh() {
		if (!configured || fetchProc.running) return;
		loading = true;
		fetchProc.running = true;
	}

	function apply(d) {
		if (!d || !d.configured) return;
		if (d.ok) {
			deadlines = d.deadlines || [];
			announcements = d.announcements || [];
			fetched = d.fetched || "";
			error = "";
		} else {
			error = d.error || "unknown error";
		}
	}

	Process {
		command: ["python3", Quickshell.shellDir + "/scripts/canvas.py", "--check"].concat(
			Settings.opt("canvasEnv", "") !== "" ? ["--env", String(Settings.opt("canvasEnv", ""))] : [])
		running: true
		stdout: StdioCollector {
			onStreamFinished: {
				try { root.configured = !!JSON.parse(text).configured; } catch (e) { root.configured = false; }
				if (root.configured) {
					cacheFile.reload();
					root.refresh();
					poll.running = true;
				}
			}
		}
	}

	FileView {
		id: cacheFile
		path: root.cachePath
		onLoaded: { try { if (!root.fetched) root.apply(JSON.parse(text())); } catch (e) {} }
	}

	Timer {
		id: poll
		interval: Math.max(60, Number(Settings.opt("canvasInterval", 900))) * 1000
		repeat: true
		onTriggered: root.refresh()
	}

	Timer {
		interval: 60000
		repeat: true
		running: root.configured
		onTriggered: root.now = new Date()
	}

	Process {
		id: fetchProc
		command: ["python3", Quickshell.shellDir + "/scripts/canvas.py", "--cache", root.cachePath].concat(
			Settings.opt("canvasEnv", "") !== "" ? ["--env", String(Settings.opt("canvasEnv", ""))] : [])
		stdout: StdioCollector {
			onStreamFinished: {
				try { root.apply(JSON.parse(text)); } catch (e) { root.error = "bad response"; }
				root.loading = false;
			}
		}
		onExited: root.loading = false
	}
}
