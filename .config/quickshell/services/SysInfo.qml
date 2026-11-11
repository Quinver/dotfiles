pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Central system metrics sampler (one process per tick for the whole shell).
// Live: cpu/mem/gpu (0..1), temps (°C), histories (60 samples, newest last),
// disks (refreshed every 60 s), uptime. Static specs are read once at startup.
// Memory is in bytes; use fmtBytes() to display.
Singleton {
	id: root

	// ---- live ----
	property real cpu: 0
	property real cpuTemp: 0
	property var cpuHistory: []
	property real memUsed: 0
	property real memTotal: 0
	readonly property real mem: memTotal > 0 ? memUsed / memTotal : 0
	property var memHistory: []
	property real gpu: 0
	property real gpuTemp: 0
	property real vramUsed: 0
	property real vramTotal: 0
	property var gpuHistory: []
	property var disks: []          // [{ mount, used, total, frac }]
	property string uptime: ""

	// ---- static ----
	property string cpuModel: ""
	property int cpuCores: 0
	property int cpuThreads: 0
	property string gpuModel: ""
	readonly property real ramTotal: memTotal
	property string kernel: ""
	property string osName: ""
	property string hostname: ""
	property string hyprlandVersion: ""
	property string motherboard: ""

	readonly property int historyLength: 60
	property string _cpuTempPath: ""
	property string _gpuDir: ""
	property string _gpuTempPath: ""
	property var _prevStat: null

	function fmtBytes(n) {
		var u = ["B", "KiB", "MiB", "GiB", "TiB"];
		var i = 0;
		while (n >= 1024 && i < u.length - 1) { n /= 1024; i++; }
		return (i === 0 || n >= 100 ? Math.round(n) : n.toFixed(1)) + " " + u[i];
	}

	function _push(arr, v) {
		var a = arr.length >= historyLength ? arr.slice(arr.length - historyLength + 1) : arr.slice();
		a.push(v);
		return a;
	}

	function _fmtUptime(sec) {
		var d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60);
		return d > 0 ? d + "d " + h + "h" : h > 0 ? h + "h " + m + "m" : m + "m";
	}

	function _parseTick(text) {
		var lines = text.split("\n"), memAvail = 0, v;
		for (var i = 0; i < lines.length; i++) {
			var p = lines[i].trim().split(/\s+/);
			if (p[0] === "cpu") {
				var n = p.slice(1).map(Number);
				var idle = n[3] + (n[4] || 0), total = 0;
				for (var j = 0; j < 8 && j < n.length; j++) total += n[j];
				if (_prevStat && total > _prevStat.total)
					cpu = Math.max(0, Math.min(1, 1 - (idle - _prevStat.idle) / (total - _prevStat.total)));
				_prevStat = { idle: idle, total: total };
			} else if (p[0] === "MemTotal:") memTotal = Number(p[1]) * 1024;
			else if (p[0] === "MemAvailable:") memAvail = Number(p[1]) * 1024;
			else if (p[0] === "up") uptime = _fmtUptime(Number(p[1]));
			else if (p[0] === "gpu") gpu = (Number(p[1]) || 0) / 100;
			else if (p[0] === "vram") vramUsed = Number(p[1]) || 0;
			else if (p[0] === "vramtotal") vramTotal = Number(p[1]) || 0;
			else if (p[0] === "ct") cpuTemp = (Number(p[1]) || 0) / 1000;
			else if (p[0] === "gt") gpuTemp = (Number(p[1]) || 0) / 1000;
		}
		memUsed = memTotal - memAvail;
		cpuHistory = _push(cpuHistory, cpu);
		memHistory = _push(memHistory, mem);
		gpuHistory = _push(gpuHistory, gpu);
	}

	function _parseDisks(text) {
		var real = ["ext4", "btrfs", "xfs", "f2fs", "ntfs", "ntfs3", "fuseblk", "exfat", "nfs", "nfs4", "cifs", "zfs"];
		var out = [], lines = text.split("\n");
		for (var i = 1; i < lines.length; i++) {
			var p = lines[i].trim().split(/\s+/);
			if (p.length < 7 || real.indexOf(p[1]) < 0) continue;
			var mount = p.slice(6).join(" ");
			if (mount.indexOf("/boot") === 0 || mount.indexOf("/var/lib/docker") === 0 || mount.indexOf("/snap") === 0) continue;
			var total = Number(p[2]), used = Number(p[3]);
			if (total > 0) out.push({ mount: mount, used: used, total: total, frac: used / total });
		}
		disks = out;
	}

	// Startup: find hwmon / GPU paths by name and read the static specs.
	Process {
		id: discover
		running: true
		command: ["sh", "-c", `
for h in /sys/class/hwmon/hwmon*; do [ "$(cat $h/name 2>/dev/null)" = k10temp ] && echo "cputemp $h/temp1_input" && break; done
best=0
for d in /sys/class/drm/card?/device; do
  t=$(cat $d/mem_info_vram_total 2>/dev/null || echo 0)
  [ "$t" -gt "$best" ] && best=$t && gd=$d
done
if [ -n "$gd" ]; then
  echo "gpudir $gd"
  for h in $gd/hwmon/hwmon*; do [ "$(cat $h/name 2>/dev/null)" = amdgpu ] && echo "gputemp $h/temp1_input" && break; done
  slot=$(basename $(readlink -f $gd))
  echo "gpumodel $(lspci -mm -s $slot 2>/dev/null | sed -E 's/^[^"]*"[^"]*" "[^"]*" "([^"]*)".*/\\1/')"
fi
echo "cpumodel $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')"
echo "threads $(nproc --all)"
echo "cores $(lscpu -p=core,socket 2>/dev/null | grep -v '#' | sort -u | wc -l)"
echo "kernel $(uname -r)"
echo "host $(cat /etc/hostname 2>/dev/null || uname -n)"
echo "os $(. /etc/os-release; echo $PRETTY_NAME)"
echo "board $(cat /sys/class/dmi/id/board_vendor /sys/class/dmi/id/board_name 2>/dev/null | tr '\\n' ' ')"
echo "hypr $(hyprctl version 2>/dev/null | head -1 | sed -E 's/^Hyprland ([^ ]+).*/\\1/')"
`]
		stdout: StdioCollector {
			onStreamFinished: {
				var lines = text.split("\n");
				for (var i = 0; i < lines.length; i++) {
					var k = lines[i].split(" ", 1)[0], v = lines[i].slice(k.length + 1).trim();
					if (k === "cputemp") root._cpuTempPath = v;
					else if (k === "gpudir") root._gpuDir = v;
					else if (k === "gputemp") root._gpuTempPath = v;
					else if (k === "gpumodel") root.gpuModel = v;
					else if (k === "cpumodel") root.cpuModel = v;
					else if (k === "threads") root.cpuThreads = Number(v);
					else if (k === "cores") root.cpuCores = Number(v);
					else if (k === "kernel") root.kernel = v;
					else if (k === "host") root.hostname = v;
					else if (k === "os") root.osName = v;
					else if (k === "board") root.motherboard = v;
					else if (k === "hypr") root.hyprlandVersion = v;
				}
				tick.running = true;
				diskTimer.running = true;
			}
		}
	}

	Timer {
		id: tick
		interval: Ui.popout === "system" || Ui.overlay === "tasks" ? 2000 : 5000   // slow down while nothing shows it
		repeat: true
		triggeredOnStart: true
		onTriggered: if (!sampler.running) sampler.running = true
	}

	Process {
		id: sampler
		command: ["sh", "-c",
			"head -1 /proc/stat; grep -E '^Mem(Total|Available):' /proc/meminfo; echo up $(cut -d' ' -f1 /proc/uptime);"
			+ "g='" + root._gpuDir + "'; [ -n \"$g\" ] && { echo gpu $(cat $g/gpu_busy_percent 2>/dev/null); echo vram $(cat $g/mem_info_vram_used 2>/dev/null); echo vramtotal $(cat $g/mem_info_vram_total 2>/dev/null); };"
			+ "c='" + root._cpuTempPath + "'; [ -n \"$c\" ] && echo ct $(cat $c 2>/dev/null);"
			+ "t='" + root._gpuTempPath + "'; [ -n \"$t\" ] && echo gt $(cat $t 2>/dev/null); true"]
		stdout: StdioCollector { onStreamFinished: root._parseTick(text) }
	}

	Timer {
		id: diskTimer
		interval: 60000
		repeat: true
		triggeredOnStart: true
		onTriggered: if (!dfProc.running) dfProc.running = true
	}

	Process {
		id: dfProc
		command: ["timeout", "5", "df", "-P", "-T", "-B1"]
		stdout: StdioCollector { onStreamFinished: root._parseDisks(text) }
	}
}
