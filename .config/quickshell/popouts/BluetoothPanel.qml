import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Bluetooth popout: power toggle, scan, device list. Discovery runs only while open.
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
		else if (!d.paired) d.pair();
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
		visible: list.count === 0
		width: parent.width
		height: Theme.rowHeight
		horizontalAlignment: Text.AlignHCenter
		muted: true
		text: !Bt.available ? "No adapter found" : !Bt.enabled ? "Bluetooth is off" : "No devices — press Scan"
	}

	ListView {
		id: list
		visible: count > 0
		width: parent.width
		height: Math.min(contentHeight, 320)
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
			title: asking ? "Forget? click again" : modelData.name || modelData.address
			subtitle: Bt.stateText(modelData) + (bat >= 0 ? " · " + bat + "%" : "")
			selected: modelData.connected
			onClicked: if (asking) root.forgetFor = ""; else root.activate(modelData)
			onRightClicked: {
				if (!modelData.paired) return;
				if (asking) { modelData.forget(); root.forgetFor = ""; }
				else { root.forgetFor = modelData.address; forgetTimer.restart(); }
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
