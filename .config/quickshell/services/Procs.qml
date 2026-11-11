pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Process list for the tasks overlay. scripts/procs.py streams one JSON line per
// sample (CPU from tick deltas, RSS, per-process GPU via amdgpu_top) and runs only
// while the overlay is open. `rows` is the filtered, optionally grouped and sorted
// view: { key, name, pid (-1 when grouped), count, pids, cpu, mem, gpu, vram, user,
// cmd, mine }. kill() signals only processes owned by the current user.
Singleton {
	id: root

	property var procs: []
	property var totals: ({ ncpu: 1, memTotal: 0, memUsed: 0, uid: -1 })
	property bool grouped: false
	property string sortKey: "cpu"      // cpu | mem | gpu | name | pid
	property bool sortDesc: true
	property string filter: ""
	property var cpuTempHistory: []
	property var gpuTempHistory: []

	readonly property bool active: Ui.overlay === "tasks"

	readonly property var rows: {
		var q = filter.trim().toLowerCase();
		var list = [];
		for (var i = 0; i < procs.length; i++) {
			var p = procs[i];
			if (q !== "" && (p.name + " " + p.user + " " + p.pid + " " + p.cmd).toLowerCase().indexOf(q) < 0) continue;
			list.push(p);
		}
		var out = [];
		if (grouped) {
			var by = {};
			list.forEach(p => {
				var g = by[p.name];
				if (!g) {
					g = by[p.name] = { key: "g:" + p.name, name: p.name, pid: -1, count: 0, pids: [], mine: false,
						cpu: 0, mem: 0, gpu: 0, vram: 0, user: p.user, cmd: p.cmd };
					out.push(g);
				}
				g.count++;
				g.pids.push(p.pid);
				g.cpu += p.cpu; g.mem += p.mem; g.gpu += p.gpu; g.vram += p.vram;
				if (p.uid === totals.uid) g.mine = true;
				if (g.user !== p.user) g.user = "mixed";
			});
		} else {
			list.forEach(p => out.push({ key: "p:" + p.pid, name: p.name, pid: p.pid, count: 1, pids: [p.pid],
				mine: p.uid === totals.uid, cpu: p.cpu, mem: p.mem, gpu: p.gpu, vram: p.vram, user: p.user, cmd: p.cmd }));
		}
		var k = sortKey, dir = sortDesc ? -1 : 1;
		out.sort((a, b) => {
			var d = k === "name" ? a.name.localeCompare(b.name) : k === "gpu" ? (a.gpu - b.gpu) || (a.vram - b.vram) : a[k === "pid" ? (grouped ? "count" : "pid") : k] - b[k === "pid" ? (grouped ? "count" : "pid") : k];
			return d !== 0 ? d * dir : a.name.localeCompare(b.name) || a.pid - b.pid;
		});
		return out;
	}

	readonly property real maxCpu: rows.reduce((m, r) => Math.max(m, r.cpu), 0.0001)
	readonly property real maxMem: rows.reduce((m, r) => Math.max(m, r.mem), 1)

	function setSort(key) {
		if (sortKey === key) sortDesc = !sortDesc;
		else { sortKey = key; sortDesc = key !== "name"; }
	}

	// Signal the user's own processes only. Returns how many were signalled.
	function kill(pids, force) {
		var mine = pids.filter(pid => {
			for (var i = 0; i < procs.length; i++) if (procs[i].pid === pid) return procs[i].uid === totals.uid;
			return false;
		});
		mine.forEach(pid => Quickshell.execDetached(["kill", force ? "-KILL" : "-TERM", String(pid)]));
		return mine.length;
	}

	function _push(arr, v) {
		var a = arr.length >= 60 ? arr.slice(arr.length - 59) : arr.slice();
		a.push(v);
		return a;
	}

	Process {
		running: root.active && Deps.has("python3")
		command: ["python3", Quickshell.shellDir + "/scripts/procs.py", "1500"]
		stdout: SplitParser {
			onRead: line => {
				var d;
				try { d = JSON.parse(line); } catch (e) { return; }
				root.totals = d.totals;
				root.procs = d.procs;
				root.cpuTempHistory = root._push(root.cpuTempHistory, SysInfo.cpuTemp);
				root.gpuTempHistory = root._push(root.gpuTempHistory, SysInfo.gpuTemp);
			}
		}
	}
}
