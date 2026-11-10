import QtQuick
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.widgets

// Windows on this monitor's active workspace. Left = focus, middle = close,
// right (anywhere on the module) = windows popout. Zero width when empty.
Row {
	id: root
	property var screen

	readonly property var monitor: Windows.monitorFor(screen)
	readonly property var wins: {
		void Windows.rev;
		return monitor && monitor.activeWorkspace ? Windows.windowsOn(monitor.activeWorkspace.id) : [];
	}

	height: Theme.barHeight
	visible: wins.length > 0

	Repeater {
		model: root.wins

		delegate: Item {
			id: item
			required property var modelData
			readonly property bool focused: modelData.activated
			readonly property bool urgent: modelData.urgent

			height: Theme.barHeight
			width: row.implicitWidth + Theme.pad * 1.2

			Rectangle {
				anchors.fill: parent
				color: item.urgent ? Theme.error : item.focused ? Theme.surfaceTop : Theme.surfaceHi
				opacity: item.urgent ? 0.25 : item.focused || mouse.containsMouse ? 1 : 0
				Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
			}
			Rectangle {
				anchors.bottom: parent.bottom
				width: parent.width
				height: 2
				color: item.urgent ? Theme.error : Theme.primary
				opacity: item.focused || item.urgent ? 1 : 0
				Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
			}

			Row {
				id: row
				anchors.centerIn: parent
				spacing: 6
				AppIcon { app: Windows.classOf(item.modelData); size: 16; anchors.verticalCenter: parent.verticalCenter }
				Txt {
					visible: item.focused
					text: item.modelData.title
					width: Math.min(implicitWidth, 260)
					color: item.urgent ? Theme.error : Theme.fg
					anchors.verticalCenter: parent.verticalCenter
				}
			}

			MouseArea {
				id: mouse
				anchors.fill: parent
				hoverEnabled: true
				acceptedButtons: Qt.LeftButton | Qt.MiddleButton
				onClicked: m => {
					if (!item.modelData.wayland) return;
					if (m.button === Qt.MiddleButton) item.modelData.wayland.close();
					else item.modelData.wayland.activate();
				}
			}
		}
	}

	TapHandler {
		acceptedButtons: Qt.RightButton
		onTapped: Ui.toggle("windows", root)
	}
}
