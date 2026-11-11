pragma Singleton
import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import qs.config

// Docker containers on configurable hosts (local or over ssh) plus local libvirt VMs.
// Hosts whose tool is missing are dropped; VMs need virsh. `available` = any host or VMs.
// Hosts: Settings.opt("containerHosts", [{name, ssh}]) - empty "ssh" = this PC.
// Nothing runs unless something holds a watcher (the docker overlay does while open):
//   watchers > 0 -> refresh now, every 10 s, and stream `docker events` for the local host.
// hostStates[name] = { status: "loading"|"ok"|"unreachable", error, containers: [...] }
// Container: { id, name, image, state, status, ports, project }
Singleton {
	id: root

	property int watchers: 0
	property string lastTab: ""   // last tab shown by the docker overlay
	// Configured hosts, minus those whose tool is missing (docker for this PC, ssh for remotes).
	readonly property var hosts: Settings.opt("containerHosts", [{ name: "This PC", ssh: "" }, { name: "headless", ssh: "headless" }])
		.filter(h => Deps.has(h.ssh ? "ssh" : "docker"))
	readonly property bool hasVms: Deps.has("virsh")
	readonly property bool available: hosts.length > 0 || hasVms
	property var hostStates: ({})
	property var vms: []
	property string vmError: ""
	readonly property bool hasLocal: hosts.some(h => !h.ssh)
	readonly property var sshOpts: ["-o", "BatchMode=yes", "-o", "ConnectTimeout=4"]

	function stateOf(name) { return hostStates[name] || { status: "loading", error: "", containers: [] }; }
	function setState(name, st) {
		var n = Object.assign({}, hostStates);
		n[name] = st;
		hostStates = n;
	}

	function safeName(s) { return /^[A-Za-z0-9][A-Za-z0-9_.-]*$/.test(s); }

	// argv that runs `cmd` (array of words, already safe) on host h.
	function argvFor(h, words, tty) {
		if (!h.ssh) return words;
		return ["ssh"].concat(tty ? ["-t"] : root.sshOpts, [h.ssh, words.join(" ")]);
	}

	function parseLabel(labels, key) {
		var parts = (labels || "").split(",");
		for (var i = 0; i < parts.length; i++)
			if (parts[i].indexOf(key + "=") === 0) return parts[i].substring(key.length + 1);
		return "";
	}

	function parsePs(text) {
		var out = [];
		var lines = text.split("\n");
		for (var i = 0; i < lines.length; i++) {
			if (!lines[i].trim()) continue;
			try {
				var o = JSON.parse(lines[i]);
				out.push({
					id: o.ID, name: o.Names, image: o.Image, state: o.State, status: o.Status,
					ports: o.Ports || "", project: parseLabel(o.Labels, "com.docker.compose.project")
				});
			} catch (e) {}
		}
		out.sort((a, b) => a.name < b.name ? -1 : 1);
		return out;
	}

	// ---- per-host list processes ----
	Instantiator {
		id: inst
		model: root.hosts
		delegate: QtObject {
			id: hostObj
			required property var modelData
			property var proc: Process {
				command: root.argvFor(hostObj.modelData, ["docker", "ps", "-a", "--format", hostObj.modelData.ssh ? "'{{json .}}'" : "{{json .}}"], false)
				stdout: StdioCollector {
					onStreamFinished: hostObj.out = text
				}
				stderr: StdioCollector {
					onStreamFinished: hostObj.err = text
				}
				onExited: code => {
					if (code === 0) root.setState(hostObj.modelData.name, { status: "ok", error: "", containers: root.parsePs(hostObj.out) });
					else {
						var e = hostObj.err.trim().split("\n").pop();
						root.setState(hostObj.modelData.name, { status: "unreachable", error: e, containers: [] });
					}
				}
			}
			property string out: ""
			property string err: ""
			function refresh() { if (!proc.running) proc.running = true; }
			Component.onCompleted: root.registry[modelData.name] = hostObj
			Component.onDestruction: delete root.registry[modelData.name]
		}
	}
	property var registry: ({})

	function refreshHost(name) { var h = registry[name]; if (h) h.refresh(); }
	function refreshAll() {
		for (var k in registry) registry[k].refresh();
		if (hasVms && !vmList.running) vmList.running = true;
	}

	Timer {
		interval: 10000
		repeat: true
		running: root.watchers > 0
		onTriggered: root.refreshAll()
	}
	onWatchersChanged: if (watchers > 0) refreshAll()

	// ---- local events: refresh instantly on any docker event ----
	Timer {
		id: debounce
		interval: 400
		onTriggered: { for (var i = 0; i < root.hosts.length; i++) if (!root.hosts[i].ssh) root.refreshHost(root.hosts[i].name); }
	}
	Process {
		running: root.watchers > 0 && root.hasLocal
		command: ["docker", "events", "--filter", "type=container", "--format", "{{json .}}"]
		stdout: SplitParser { onRead: line => debounce.restart() }
	}

	// ---- VMs ----
	Process {
		id: vmList
		command: ["virsh", "-c", "qemu:///system", "list", "--all"]
		stdout: StdioCollector {
			onStreamFinished: {
				var out = [];
				var lines = text.split("\n");
				for (var i = 2; i < lines.length; i++) {
					var m = lines[i].trim().match(/^(\S+)\s+(\S+)\s+(.+)$/);
					if (m) out.push({ name: m[2], state: m[3].trim() });
				}
				root.vms = out;
				root.vmError = "";
			}
		}
		onExited: code => { if (code !== 0) { root.vms = []; root.vmError = "virsh unavailable"; } }
	}

	// ---- actions ----
	// Runs argv, then calls done(). Objects clean themselves up.
	Component { id: runner; Process { property var done: null; onExited: { if (done) done(); destroy(); } } }
	function run(argv, done) {
		var p = runner.createObject(root, { command: argv, done: done });
		p.running = true;
	}
	function hostByName(name) {
		for (var i = 0; i < hosts.length; i++) if (hosts[i].name === name) return hosts[i];
		return null;
	}

	function containerAction(hostName, verb, c) {
		var h = hostByName(hostName);
		if (!h || !safeName(c.name) || ["start", "stop", "restart"].indexOf(verb) < 0) return;
		run(argvFor(h, ["docker", verb, c.name], false), () => refreshHost(hostName));
	}
	function start(hostName, c) { containerAction(hostName, "start", c); }
	function stop(hostName, c) { containerAction(hostName, "stop", c); }
	function restart(hostName, c) { containerAction(hostName, "restart", c); }

	function openLogs(hostName, c) {
		var h = hostByName(hostName);
		if (!h || !safeName(c.name)) return;
		Quickshell.execDetached(["alacritty", "-e"].concat(argvFor(h, ["docker", "logs", "-f", "--tail", "200", c.name], true)));
	}
	function openShell(hostName, c) {
		var h = hostByName(hostName);
		if (!h || !safeName(c.name)) return;
		Quickshell.execDetached(["alacritty", "-e"].concat(argvFor(h, ["docker", "exec", "-it", c.name, "sh"], true)));
	}

	function vmStart(name) { if (safeName(name)) run(["virsh", "-c", "qemu:///system", "start", name], () => { if (!vmList.running) vmList.running = true; }); }
	function vmShutdown(name) { if (safeName(name)) run(["virsh", "-c", "qemu:///system", "shutdown", name], () => { if (!vmList.running) vmList.running = true; }); }
	function openVm(name) {
		if (safeName(name)) Quickshell.execDetached(["virt-manager", "--connect", "qemu:///system", "--show-domain-console", name]);
	}
}
