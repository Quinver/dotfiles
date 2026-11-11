pragma Singleton
import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Network state on top of Quickshell.Networking (NetworkManager).
// Bars read kind / connected / strength; NetworkPanel additionally calls
// scan(true|false) while open and holds a "watcher" (watchers++ / watchers--)
// so /proc/net/dev is only sampled (every 2 s) while something shows the rates.
// VPN: WireGuard / VPN profiles via nmcli, refreshed from `nmcli monitor` events (no polling).
// Speed test: Ookla CLI run by a service Process so closing the popout does not kill it;
// the last result stays in memory.
// signalStrength is already 0..1 (checked on this machine).
Singleton {
	id: root

	readonly property var devices: Networking.devices.values
	readonly property var wired: {
		var d = devices;
		for (var i = 0; i < d.length; i++) if (d[i].type === DeviceType.Wired && d[i].connected) return d[i];
		return null;
	}
	readonly property var wifiDevice: {
		var d = devices;
		for (var i = 0; i < d.length; i++) if (d[i].type === DeviceType.Wifi) return d[i];
		return null;
	}
	readonly property bool wifiEnabled: Networking.wifiEnabled
	// Rebuilt only when membership / connected state changes (not on every signal
	// wobble) so a ListView on it keeps its scroll position and open inputs.
	property var networks: []
	readonly property var activeNetwork: {
		for (var i = 0; i < networks.length; i++) if (networks[i].connected) return networks[i];
		return null;
	}
	readonly property string kind: wired ? "ethernet" : activeNetwork ? "wifi" : wifiEnabled ? "none" : "off"
	readonly property bool connected: kind === "ethernet" || kind === "wifi"
	readonly property string ssid: activeNetwork ? activeNetwork.name : ""
	readonly property real strength: activeNetwork ? clamp(activeNetwork.signalStrength) : 0
	// Interface carrying the traffic ("" when offline).
	readonly property string iface: kind === "ethernet" ? wired.name : kind === "wifi" ? wifiDevice.name : ""

	property int watchers: 0
	property real rxRate: 0
	property real txRate: 0
	property string ip: ""
	property string lastError: ""
	property string errorNetwork: ""

	function clamp(v) { return Math.max(0, Math.min(1, v > 1 ? v / 100 : v)); }

	// Connected first, then by strength; hidden SSIDs dropped, duplicates (several APs) merged.
	function buildNetworks(list) {
		var best = {};
		for (var i = 0; i < list.length; i++) {
			var n = list[i];
			if (!n.name) continue;
			var cur = best[n.name];
			if (!cur || (n.connected && !cur.connected) || (n.connected === cur.connected && n.signalStrength > cur.signalStrength))
				best[n.name] = n;
		}
		var out = Object.keys(best).map(k => best[k]);
		out.sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength));
		return out;
	}

	function secured(network) {
		return network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe;
	}

	function securityText(network) {
		if (!secured(network)) return "Open";
		switch (network.security) {
		case WifiSecurityType.Sae: case WifiSecurityType.Wpa3SuiteB192: return "WPA3";
		case WifiSecurityType.Wpa2Psk: return "WPA2";
		case WifiSecurityType.Wpa2Eap: case WifiSecurityType.WpaEap: return "Enterprise";
		case WifiSecurityType.WpaPsk: return "WPA";
		case WifiSecurityType.StaticWep: case WifiSecurityType.DynamicWep: return "WEP";
		default: return "Secured";
		}
	}

	function setWifiEnabled(on) { Networking.wifiEnabled = on; }
	property bool scanWanted: false
	function scan(on) { scanWanted = on; }
	Binding { target: root.wifiDevice; property: "scannerEnabled"; value: root.scanWanted; when: root.wifiDevice !== null }

	function connect(network, psk) {
		lastError = "";
		if (network.known || !secured(network)) network.connect();
		else network.connectWithPsk(psk || "");
	}
	function disconnect(network) { network.disconnect(); }
	function forget(network) { network.forget(); }

	function fmtRate(bytesPerSec) {
		var v = bytesPerSec, u = ["B/s", "KB/s", "MB/s", "GB/s"], i = 0;
		while (v >= 1024 && i < u.length - 1) { v /= 1024; i++; }
		return (i === 0 || v >= 100 ? Math.round(v) : v.toFixed(1)) + " " + u[i];
	}

	function failText(reason) {
		switch (reason) {
		case ConnectionFailReason.NoSecrets: return "Wrong or missing password";
		case ConnectionFailReason.WifiAuthTimeout: return "Authentication timed out";
		case ConnectionFailReason.WifiClientDisconnected: return "Disconnected by the access point";
		case ConnectionFailReason.WifiClientFailed: return "Connection failed";
		case ConnectionFailReason.WifiNetworkLost: return "Network went out of range";
		default: return "Could not connect";
		}
	}

	function refresh() {
		var n = buildNetworks(wifiDevice ? wifiDevice.networks.values : []);
		var key = n.map(x => x.name + (x.connected ? "*" : "")).join("|");
		if (key === _key) return;
		_key = key;
		networks = n;
	}
	property string _key: "\0"
	onWifiDeviceChanged: refresh()
	Component.onCompleted: refresh()
	Connections {
		target: root.wifiDevice ? root.wifiDevice.networks : null
		function onValuesChanged() { refreshTimer.restart(); }
	}
	Timer { id: refreshTimer; interval: 200; onTriggered: root.refresh() }

	// One listener per network object: connection failures and connected changes.
	Instantiator {
		model: root.wifiDevice ? root.wifiDevice.networks : null
		delegate: Connections {
			required property var modelData
			target: modelData
			function onConnectedChanged() { refreshTimer.restart(); }
			function onConnectionFailed(reason) {
				root.errorNetwork = modelData.name;
				root.lastError = root.failText(reason);
			}
		}
	}

	// ---- throughput ----
	property real lastRx: -1
	property real lastTx: -1
	property real lastT: 0
	onIfaceChanged: { lastRx = -1; rxRate = 0; txRate = 0; ipProc.running = false; ip = ""; if (iface) ipProc.running = true; }

	FileView {
		id: dev
		path: "/proc/net/dev"
		onLoaded: {
			var lines = text().split("\n");
			for (var i = 2; i < lines.length; i++) {
				var l = lines[i].trim();
				if (l.indexOf(root.iface + ":") !== 0) continue;
				var f = l.substring(l.indexOf(":") + 1).trim().split(/\s+/);
				var rx = Number(f[0]), tx = Number(f[8]), now = Date.now();
				if (root.lastRx >= 0 && now > root.lastT) {
					var dt = (now - root.lastT) / 1000;
					root.rxRate = Math.max(0, (rx - root.lastRx) / dt);
					root.txRate = Math.max(0, (tx - root.lastTx) / dt);
				}
				root.lastRx = rx; root.lastTx = tx; root.lastT = now;
				return;
			}
		}
	}
	Timer {
		interval: 2000
		repeat: true
		triggeredOnStart: true
		running: root.watchers > 0 && root.iface !== ""
		onTriggered: dev.reload()
		onRunningChanged: if (!running) root.lastRx = -1
	}

	Process {
		id: ipProc
		command: ["sh", "-c", "ip -4 -o addr show dev " + root.iface + " | awk '{print $4; exit}'"]
		stdout: StdioCollector { onStreamFinished: root.ip = text.trim().split("/")[0] }
	}
	onWatchersChanged: if (watchers > 0 && iface) ipProc.running = true
	// Address can change without the interface changing (DHCP renew, new connection).
	onConnectedChanged: if (iface) ipProc.running = true

	// ---- VPN ----
	property var vpns: []   // [{ name, active }]
	readonly property string vpnActive: {
		for (var i = 0; i < vpns.length; i++) if (vpns[i].active) return vpns[i].name;
		return "";
	}

	function setVpn(name, on) {
		var q = n => "'" + n.replace(/'/g, "'\\''") + "'";
		var cmd = "";
		if (on && vpnActive && vpnActive !== name) cmd += "nmcli con down id " + q(vpnActive) + "; ";
		cmd += "nmcli con " + (on ? "up" : "down") + " id " + q(name);
		vpnSet.command = ["sh", "-c", cmd];
		vpnSet.running = true;
	}

	Process { id: vpnSet; onExited: vpnProc.running = true }
	Process {
		id: vpnProc
		command: ["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE", "con", "show"]
		running: root.available
		stdout: StdioCollector {
			onStreamFinished: {
				var out = [];
				text.split("\n").forEach(l => {
					var f = l.split(":");
					if (f.length < 3 || (f[f.length - 2] !== "wireguard" && f[f.length - 2] !== "vpn")) return;
					out.push({ name: f.slice(0, -2).join(":").replace(/\\/g, ""), active: f[f.length - 1] === "yes" });
				});
				out.sort((a, b) => a.name.localeCompare(b.name));
				var key = JSON.stringify(out);
				if (key !== root._vpnKey) { root._vpnKey = key; root.vpns = out; }
			}
		}
	}
	property string _vpnKey: ""
	Timer { id: vpnTimer; interval: 400; onTriggered: if (!vpnProc.running) vpnProc.running = true }
	Process {
		command: ["nmcli", "monitor"]
		running: root.available
		stdout: SplitParser { onRead: vpnTimer.restart() }
	}

	// ---- speed test ----
	property bool speedRunning: false
	property string speedError: ""
	readonly property bool available: Deps.has("nmcli")
	readonly property bool speedtestAvailable: Deps.has("speedtest")
	property var speedResult: null   // { down, up (Mbps), ping (ms), server, isp, time }

	function runSpeedtest() {
		if (speedRunning || !speedtestAvailable) return;
		speedError = "";
		speedRunning = true;
		speedProc.running = true;
	}

	Process {
		id: speedProc
		command: ["speedtest", "-f", "json", "--accept-license", "--accept-gdpr"]
		stdout: StdioCollector {
			onStreamFinished: {
				try {
					var j = JSON.parse(text);
					root.speedResult = {
						down: j.download.bandwidth * 8 / 1e6,
						up: j.upload.bandwidth * 8 / 1e6,
						ping: j.ping.latency,
						server: j.server.name,
						isp: j.isp,
						time: new Date()
					};
				} catch (e) { root.speedError = "Speed test failed"; }
			}
		}
		onExited: root.speedRunning = false
	}
}
