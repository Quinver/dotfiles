pragma Singleton
import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs.config

// Bluetooth state on top of Quickshell.Bluetooth (BlueZ).
// `available` is false when there is no adapter at all. If rfkill has the radio
// soft-blocked, setEnabled(true) first runs `rfkill unblock bluetooth`
// (/dev/rfkill is writable by the user session via an ACL on this machine).
Singleton {
	id: root

	readonly property var adapter: Bluetooth.defaultAdapter
	readonly property bool available: adapter !== null
	readonly property bool enabled: adapter ? adapter.enabled : false
	readonly property bool discovering: adapter ? adapter.discovering : false
	readonly property bool blocked: adapter ? adapter.state === BluetoothAdapterState.Blocked : false
	// Connected -> paired -> others; rebuilt on membership / state / name changes.
	property var devices: []
	readonly property int connectedCount: devices.filter(d => d.connected).length

	function setEnabled(on) {
		if (!adapter) return;
		if (on && blocked) unblock.running = true;
		else adapter.enabled = on;
	}
	function setDiscovering(on) { if (adapter && adapter.enabled) adapter.discovering = on; }

	// 0..100, or -1 when the device reports no battery.
	function battery(device) { return device.batteryAvailable ? Math.round(device.battery * 100) : -1; }

	function stateText(device) {
		if (device.pairing) return "Pairing…";
		switch (device.state) {
		case BluetoothDeviceState.Connecting: return "Connecting…";
		case BluetoothDeviceState.Disconnecting: return "Disconnecting…";
		case BluetoothDeviceState.Connected: return "Connected";
		default: return device.paired ? "Paired" : "Not paired";
		}
	}

	// BlueZ icon names (freedesktop-style) onto the glyphs we have.
	function iconFor(device) {
		var i = device.icon || "";
		if (i.indexOf("audio-head") === 0) return Icons.headphones;
		if (i === "audio-card") return Icons.volumeHigh;
		if (i === "input-gaming") return Icons.gamepad;
		if (i === "input-keyboard") return Icons.keyboard;
		if (i === "computer") return Icons.desktop;
		if (i === "video-display") return Icons.tv;
		if (i.indexOf("camera") === 0) return Icons.camera;
		return Icons.bluetooth;
	}

	function rebuild() {
		var list = adapter ? adapter.devices.values : [];
		var out = list.filter(d => d.paired || (d.name && d.name !== d.address.replace(/:/g, "-")));
		out.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name));
		var key = out.map(d => d.address + (d.connected ? "c" : "") + (d.paired ? "p" : "") + d.name).join("|");
		if (key === _key) return;
		_key = key;
		devices = out;
	}
	property string _key: "\0"
	onAdapterChanged: rebuild()
	Component.onCompleted: rebuild()

	Connections {
		target: root.adapter ? root.adapter.devices : null
		function onValuesChanged() { rebuildTimer.restart(); }
	}
	Instantiator {
		model: root.adapter ? root.adapter.devices : null
		delegate: Connections {
			required property var modelData
			target: modelData
			function onConnectedChanged() { rebuildTimer.restart(); }
			function onPairedChanged() { rebuildTimer.restart(); }
			function onNameChanged() { rebuildTimer.restart(); }
		}
	}
	Timer { id: rebuildTimer; interval: 150; onTriggered: root.rebuild() }

	Process {
		id: unblock
		command: ["rfkill", "unblock", "bluetooth"]
		onExited: if (root.adapter) root.adapter.enabled = true
	}
}
