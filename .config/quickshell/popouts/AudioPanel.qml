import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Audio popout: output + input (master row and device list) and per-app streams.
Column {
	id: root

	width: Theme.popoutWidth
	spacing: Theme.spacing

	component MasterRow: RowLayout {
		id: row
		property string onIcon: Icons.volumeHigh
		property string offIcon: Icons.volumeOff
		property real value: 0
		property bool muted: false
		signal volumeMoved(real v)
		signal muteClicked()

		width: root.width
		spacing: Theme.spacing
		Btn { icon: row.muted ? row.offIcon : row.onIcon; flat: true; onClicked: row.muteClicked() }
		Slider { Layout.fillWidth: true; value: row.value; enabled: !row.muted; onMoved: v => row.volumeMoved(v) }
		Txt { text: Math.round(row.value * 100) + "%"; mono: true; dim: true; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight }
	}

	component DeviceList: ListView {
		property var current: null
		signal picked(var node)

		width: root.width
		height: Math.min(contentHeight, Theme.rowHeight * 4)
		clip: true
		delegate: ListItem {
			required property var modelData
			width: ListView.view.width
			icon: Icons.headphones
			title: Audio.label(modelData)
			selected: modelData === ListView.view.current
			onClicked: ListView.view.picked(modelData)
		}
	}

	Header { width: parent.width; title: "Output" }
	MasterRow {
		value: Audio.volume
		muted: Audio.muted
		onVolumeMoved: v => Audio.setVolume(v)
		onMuteClicked: Audio.toggleMute()
	}
	DeviceList { model: Audio.sinks; current: Audio.sink; onPicked: n => Audio.setDefaultSink(n) }

	Sep { width: parent.width }
	Header { width: parent.width; title: "Input" }
	MasterRow {
		onIcon: Icons.mic
		offIcon: Icons.micOff
		value: Audio.micVolume
		muted: Audio.micMuted
		onVolumeMoved: v => Audio.setMicVolume(v)
		onMuteClicked: Audio.toggleMicMute()
	}
	DeviceList { model: Audio.sources; current: Audio.source; onPicked: n => Audio.setDefaultSource(n) }

	Sep { width: parent.width }
	Header { width: parent.width; title: "Applications" }
	Txt {
		visible: Audio.streams.length === 0
		width: parent.width
		height: Theme.rowHeight
		text: "Nothing is playing"
		muted: true
		horizontalAlignment: Text.AlignHCenter
	}
	ListView {
		width: parent.width
		height: Math.min(contentHeight, Theme.rowHeight * 5)
		visible: Audio.streams.length > 0
		clip: true
		model: Audio.streams
		delegate: RowLayout {
			required property var modelData
			readonly property var au: modelData.audio
			width: ListView.view.width
			height: Theme.rowHeight
			spacing: Theme.spacing
			AppIcon { app: Audio.streamIcon(modelData); size: Theme.iconSize + 2; Layout.leftMargin: Theme.spacing }
			Txt { text: Audio.streamName(modelData); Layout.preferredWidth: 100; elide: Text.ElideRight }
			Slider {
				Layout.fillWidth: true
				value: au ? au.volume : 0
				enabled: au !== null && !au.muted
				onMoved: v => { if (au) au.volume = v; }
			}
			Btn {
				icon: au && au.muted ? Icons.volumeOff : Icons.volumeHigh
				flat: true
				onClicked: { if (au) au.muted = !au.muted; }
			}
		}
	}

	Sep { width: parent.width }
	Btn {
		text: "Mixer"
		flat: true
		width: parent.width
		onClicked: { Quickshell.execDetached(["pwvucontrol"]); Ui.close(); }
	}
}
