import QtQuick
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.widgets

// Per-monitor workspace strip: persistent ids plus workspaces that exist on this
// monitor, then special workspaces. Click activates, scrolling steps through them.
Row {
	id: root
	property var screen

	readonly property var monitor: Windows.monitorFor(screen)
	readonly property var entries: {
		void Windows.rev;
		var ids = {};
		var list = [];
		var specials = [];
		var wss = Hyprland.workspaces.values;
		function add(id, ws) {
			if (ws && (id < 0 || ws.name.indexOf("special:") === 0)) { specials.push({ id: id, ws: ws, special: true }); return; }
			if (ids[id]) return;
			ids[id] = true;
			list.push({ id: id, ws: ws, special: false });
		}
		if (monitor) {
			Windows.persistentFor(monitor.name).forEach(id => add(id, wss.find(w => w.id === id) || null));
			wss.forEach(w => { if (w.monitor && w.monitor.name === monitor.name) add(w.id, w); });
		}
		list.sort((a, b) => a.id - b.id);
		return list.concat(specials);
	}

	function step(dir) {
		var real = entries.filter(e => !e.special && e.ws);
		if (real.length === 0 || !monitor) return;
		var cur = real.findIndex(e => monitor.activeWorkspace && e.id === monitor.activeWorkspace.id);
		var next = Math.max(0, Math.min(real.length - 1, (cur < 0 ? 0 : cur) + dir));
		if (next !== cur) real[next].ws.activate();
	}

	height: Theme.barHeight

	Repeater {
		model: root.entries

		delegate: Item {
			id: cell
			required property var modelData
			readonly property var ws: modelData.ws
			readonly property var wins: { void Windows.rev; return Windows.windowsOn(modelData.id); }
			readonly property bool active: root.monitor && root.monitor.activeWorkspace && root.monitor.activeWorkspace.id === modelData.id
			readonly property bool focusedHere: active && root.monitor.focused
			readonly property bool urgent: ws ? ws.urgent : false
			readonly property color textColor: urgent ? Theme.error : focusedHere ? Theme.fg : wins.length > 0 ? Theme.fgDim : Theme.fgMuted
			readonly property color lineColor: urgent ? Theme.error : focusedHere ? Theme.primary : Theme.fgMuted

			height: Theme.barHeight
			width: Math.max(Theme.barHeight, content.implicitWidth + Theme.pad)

			Rectangle {
				anchors.fill: parent
				color: cell.focusedHere ? Theme.surfaceTop : Theme.surfaceHi
				opacity: cell.focusedHere || mouse.containsMouse ? 1 : 0
				Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
			}
			Rectangle {
				anchors.bottom: parent.bottom
				width: parent.width
				height: 2
				color: cell.lineColor
				opacity: cell.active || cell.urgent ? 1 : 0
				Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
				Behavior on color { ColorAnimation { duration: Theme.animFast } }
			}

			Row {
				id: content
				anchors.centerIn: parent
				spacing: 4

				Icon { visible: cell.modelData.special; glyph: Icons.star; color: cell.textColor; anchors.verticalCenter: parent.verticalCenter }
				Txt {
					visible: !cell.modelData.special
					text: cell.modelData.id
					size: Theme.fontSmall
					bold: cell.focusedHere
					color: cell.textColor
					anchors.verticalCenter: parent.verticalCenter
				}
				Repeater {
					model: cell.wins.slice(0, 4)
					AppIcon {
						required property var modelData
						app: Windows.classOf(modelData)
						size: 14
						anchors.verticalCenter: parent.verticalCenter
					}
				}
				Txt {
					visible: cell.wins.length > 4
					text: "+" + (cell.wins.length - 4)
					size: Theme.fontSmall
					color: cell.textColor
					anchors.verticalCenter: parent.verticalCenter
				}
			}

			MouseArea {
				id: mouse
				anchors.fill: parent
				hoverEnabled: true
				onClicked: {
					if (cell.ws) cell.ws.activate();
					else Hyprland.dispatch("hl.dsp.focus({ workspace = " + cell.modelData.id + " })");
				}
			}
		}
	}

	WheelHandler {
		acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
		onWheel: event => { if (event.angleDelta.y !== 0) root.step(event.angleDelta.y < 0 ? 1 : -1); }
	}
}
