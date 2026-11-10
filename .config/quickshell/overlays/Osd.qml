import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Volume OSD: one always-present, click-through layer window whose `screen` is
// set to the focused monitor each time it is shown. Triggered by Audio.osdTick.
Scope {
	id: root

	property bool shown: false
	property var target: null

	Connections {
		target: Audio
		function onOsdTickChanged() {
			if (!root.shown) root.target = Ui.focusedScreen();
			root.shown = true;
			hide.restart();
		}
	}
	Timer { id: hide; interval: 1400; onTriggered: root.shown = false }

	PanelWindow {
		screen: root.target
		visible: root.target !== null && (root.shown || box.opacity > 0)
		color: "transparent"
		WlrLayershell.layer: WlrLayer.Overlay
		WlrLayershell.namespace: "qs-osd"
		WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
		exclusionMode: ExclusionMode.Ignore
		anchors.bottom: true
		margins.bottom: 80
		implicitWidth: 260
		implicitHeight: 44
		mask: Region { item: box }

		Box {
			id: box
			anchors.fill: parent
			opacity: root.shown ? 1 : 0
			Behavior on opacity { NumberAnimation { duration: Theme.anim } }

			Row {
				anchors.fill: parent
				anchors.leftMargin: Theme.pad
				anchors.rightMargin: Theme.pad
				spacing: Theme.pad

				Icon {
					anchors.verticalCenter: parent.verticalCenter
					glyph: Audio.muted || Audio.volume <= 0 ? Icons.volumeOff : Audio.volume < 0.5 ? Icons.volumeLow : Icons.volumeHigh
					color: Audio.muted ? Theme.fgMuted : Theme.fg
				}
				Meter {
					anchors.verticalCenter: parent.verticalCenter
					width: parent.width - Theme.iconSize * 2 - 52 - parent.spacing * 2
					value: Math.min(1, Audio.volume)
					warnAt: 2
					critAt: 2
					fill: Audio.muted ? Theme.fgMuted : Theme.primary
				}
				Txt {
					anchors.verticalCenter: parent.verticalCenter
					width: 40
					horizontalAlignment: Text.AlignRight
					mono: true
					muted: Audio.muted
					text: Audio.muted ? "MUTE" : Math.round(Audio.volume * 100) + "%"
				}
			}
		}
	}
}
