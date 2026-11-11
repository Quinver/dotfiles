import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Bluetooth popout: power toggle, scan (auto-stops after 30 s), paired devices with
// trust / forget, and a "New devices" list with Pair. Discovery stops when closed.
Column {
	id: root

	property string forgetFor: ""   // device address waiting for a second click to forget

	width: Theme.popoutWidth
	spacing: Theme.spacing

	Component.onDestruction: Bt.setDiscovering(false)

	Timer { id: forgetTimer; interval: 3000; onTriggered: root.forgetFor = "" }

	function activate(d) {
		root.forgetFor = "";
		if (d.pairing) d.cancelPair();
		else if (d.connected) d.disconnect();
		else d.connect();
	}

	Header {
		width: parent.width
		title: "Bluetooth"
		Btn {
			visible: Bt.enabled
			text: "Scan"
			checked: Bt.discovering
			implicitHeight: 24
			onClicked: Bt.setDiscovering(!Bt.discovering)
		}
		Toggle { checked: Bt.enabled; onToggled: v => Bt.setEnabled(v) }
	}

	Txt {
		visible: list.count === 0 || !Bt.enabled
		width: parent.width
		height: Theme.rowHeight
		horizontalAlignment: Text.AlignHCenter
		muted: true
		text: !Bt.available ? "No adapter found" : !Bt.enabled ? "Bluetooth is off" : "No paired devices"
	}

	ListView {
		id: list
		visible: count > 0
		width: parent.width
		height: Math.min(contentHeight, 280)
		clip: true
		model: Bt.enabled ? Bt.devices : []

		delegate: ListItem {
			id: row
			required property var modelData
			readonly property bool asking: root.forgetFor === modelData.address
			readonly property int bat: Bt.battery(modelData)
			width: ListView.view.width
			icon: Bt.iconFor(modelData)
			iconColor: modelData.connected ? Theme.primary : Theme.fgDim
			title: modelData.name || modelData.address
			subtitle: Bt.stateText(modelData) + (bat >= 0 ? " · " + bat + "%" : "")
			selected: modelData.connected
			onClicked: root.activate(modelData)
			Btn {
				flat: true
				icon: Icons.star
				checked: row.modelData.trusted
				implicitHeight: 24
				onClicked: row.modelData.trusted = !row.modelData.trusted
			}
			Btn {
				flat: true
				danger: row.asking
				icon: row.asking ? "" : Icons.trash
				text: row.asking ? "Forget?" : ""
				implicitHeight: 24
				onClicked: {
					if (row.asking) { row.modelData.forget(); root.forgetFor = ""; }
					else { root.forgetFor = row.modelData.address; forgetTimer.restart(); }
				}
			}
		}
	}

	Header { visible: Bt.enabled; width: parent.width; title: "New devices" }

	Txt {
		visible: Bt.enabled && fresh.count === 0
		width: parent.width
		height: Theme.rowHeight
		horizontalAlignment: Text.AlignHCenter
		muted: true
		text: Bt.discovering ? "Searching…" : "None found — press Scan"
	}

	ListView {
		id: fresh
		visible: Bt.enabled && count > 0
		width: parent.width
		height: Math.min(contentHeight, 200)
		clip: true
		model: Bt.enabled ? Bt.newDevices : []

		delegate: ListItem {
			id: frow
			required property var modelData
			width: ListView.view.width
			icon: Bt.iconFor(modelData)
			title: modelData.name
			subtitle: modelData.pairing ? "Pairing…" : modelData.address
			onClicked: if (!modelData.pairing) Bt.pairAndConnect(modelData)
			Btn {
				text: frow.modelData.pairing ? "Cancel" : "Pair"
				accent: !frow.modelData.pairing
				implicitHeight: 24
				onClicked: frow.modelData.pairing ? frow.modelData.cancelPair() : Bt.pairAndConnect(frow.modelData)
			}
		}
	}

	Sep { width: parent.width }

	Btn {
		width: parent.width
		flat: true
		icon: Icons.cog
		text: "Bluetooth manager"
		onClicked: { Quickshell.execDetached(["blueman-manager"]); Ui.close(); }
	}
}
