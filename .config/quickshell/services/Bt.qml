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
// Discovery stops by itself after 30 s. `devices` holds paired devices, `newDevices`
// the named unpaired ones seen while scanning; pairAndConnect() pairs, trusts, connects.
Singleton {
	id: root

	readonly property var adapter: Bluetooth.defaultAdapter
	readonly property bool available: adapter !== null
	readonly property bool enabled: adapter ? adapter.enabled : false
	readonly property bool discovering: adapter ? adapter.discovering : false
	readonly property bool blocked: adapter ? adapter.state === BluetoothAdapterState.Blocked : false
	// Connected -> paired -> others; rebuilt on membership / state / name changes.
	property var devices: []
	property var newDevices: []
	property string pendingPair: ""   // address of a device being paired + trusted + connected
	readonly property int connectedCount: devices.filter(d => d.connected).length

	function setEnabled(on) {
		if (!adapter) return;
		if (on && blocked) unblock.running = true;
		else adapter.enabled = on;
	}
	function setDiscovering(on) { if (adapter && adapter.enabled) adapter.discovering = on; }
	Timer { interval: 30000; running: root.discovering; onTriggered: root.setDiscovering(false) }

	function pairAndConnect(device) {
		pendingPair = device.address;
		device.pair();
	}

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
		var named = list.filter(d => d.name && d.name !== d.address.replace(/:/g, "-"));
		var out = list.filter(d => d.paired);
		var fresh = named.filter(d => !d.paired);
		out.sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name));
		fresh.sort((a, b) => a.name.localeCompare(b.name));
		var key = out.concat(fresh).map(d => d.address + (d.connected ? "c" : "") + (d.paired ? "p" : "") + d.name).join("|");
		if (key === _key) return;
		_key = key;
		devices = out;
		newDevices = fresh;
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
			function onPairedChanged() {
				rebuildTimer.restart();
				if (modelData.paired && root.pendingPair === modelData.address) {
					root.pendingPair = "";
					modelData.trusted = true;
					modelData.connect();
				}
			}
			function onPairingChanged() {
				if (!modelData.pairing && !modelData.paired && root.pendingPair === modelData.address) root.pendingPair = "";
			}
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
