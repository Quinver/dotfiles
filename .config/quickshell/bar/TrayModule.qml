import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.config
import qs.widgets

// StatusNotifier tray: a row of 16 px icons. Left = activate (or menu when the
// item is menu-only), right = menu, middle = secondary action, wheel = scroll.
// Passive items are hidden (apps use Passive for "nothing to say right now").
Item {
	id: root
	property var screen

	readonly property var shown: SystemTray.items.values.filter(i => i.status !== Status.Passive)

	visible: shown.length > 0
	implicitWidth: row.implicitWidth + Theme.pad
	implicitHeight: Theme.barHeight

	Row {
		id: row
		anchors.centerIn: parent
		spacing: 2

		Repeater {
			model: root.shown

			delegate: Item {
				id: cell
				required property var modelData
				width: 24
				height: Theme.barHeight

				Rectangle {
					anchors.centerIn: parent
					width: parent.width
					height: 24
					color: Theme.surfaceHi
					opacity: mouse.containsMouse ? 1 : 0
				}

				AppIcon {
					id: icon
					anchors.centerIn: parent
					size: 16
					source: cell.modelData.icon
				}

				QsMenuAnchor {
					id: menu
					menu: cell.modelData.menu
					anchor.item: icon
					anchor.edges: Edges.Bottom
					anchor.gravity: Edges.Bottom
				}

				MouseArea {
					id: mouse
					anchors.fill: parent
					hoverEnabled: true
					acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
					onClicked: m => {
						var it = cell.modelData;
						if (m.button === Qt.LeftButton) {
							if (it.onlyMenu && it.hasMenu) menu.open(); else it.activate();
						} else if (m.button === Qt.RightButton) {
							if (it.hasMenu) menu.open(); else it.secondaryActivate();
						} else it.secondaryActivate();
					}
					onWheel: w => { if (w.angleDelta.y !== 0) cell.modelData.scroll(w.angleDelta.y, false); }
				}
			}
		}
	}
}
