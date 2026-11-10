import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Power / session menu overlay (Ui.overlay === "power").
// Left/Right/Tab move, Enter/Space or a shortcut letter activates, Esc closes.
// Destructive actions need a second activation within 3 s ("Confirm?").
LazyLoader {
	active: Ui.overlay === "power"

	PanelWindow {
		id: win
		screen: Ui.overlayScreen
		WlrLayershell.layer: WlrLayer.Overlay
		WlrLayershell.namespace: "qs-power"
		WlrLayershell.keyboardFocus: Ui.testMode ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
		exclusionMode: ExclusionMode.Ignore
		anchors { top: true; bottom: true; left: true; right: true }
		color: Qt.rgba(0, 0, 0, 0.35)

		readonly property string lockCommand: Settings.opt("lockCommand", "")
		readonly property var actions: {
			var list = [];
			if (lockCommand !== "") list.push({ id: "lock", label: "Lock", key: "K", icon: Icons.lock, cmd: ["sh", "-c", lockCommand], confirm: false });
			list.push({ id: "suspend", label: "Suspend", key: "S", icon: Icons.moon, cmd: ["systemctl", "suspend"], confirm: false });
			list.push({ id: "logout", label: "Log out", key: "L", icon: Icons.logout, cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"], confirm: true });
			list.push({ id: "reboot", label: "Reboot", key: "R", icon: Icons.refresh, cmd: ["systemctl", "reboot"], confirm: true });
			list.push({ id: "poweroff", label: "Shut down", key: "P", icon: Icons.power, cmd: ["systemctl", "poweroff"], confirm: true });
			return list;
		}

		property int sel: 0
		property string armed: ""      // id of the action waiting for confirmation

		function activate(i) {
			var a = actions[i];
			if (!a) return;
			sel = i;
			if (a.confirm && armed !== a.id) {
				armed = a.id;
				disarm.restart();
				return;
			}
			var cmd = a.cmd;
			Ui.close();
			Quickshell.execDetached(cmd);
		}

		function activateKey(key) {
			for (var i = 0; i < actions.length; i++) if (actions[i].key === key) { activate(i); return true; }
			return false;
		}

		function move(d) {
			sel = (sel + d + actions.length) % actions.length;
			armed = "";
		}

		function uptimeText(raw) {
			var s = Math.floor(parseFloat(raw));
			if (isNaN(s)) return "";
			var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
			return "up " + (d > 0 ? d + "d " : "") + (h > 0 || d > 0 ? h + "h " : "") + m + "m";
		}

		Timer { id: disarm; interval: 3000; onTriggered: win.armed = "" }

		property string up: ""
		property string hostName: ""
		FileView {
			path: "/proc/uptime"
			onLoaded: win.up = win.uptimeText(text())
		}
		FileView {
			path: "/etc/hostname"
			onLoaded: win.hostName = text().trim()
		}

		Component.onCompleted: keys.forceActiveFocus()
		onVisibleChanged: if (visible) keys.forceActiveFocus()
		onWindowConnected: keys.forceActiveFocus()

		MouseArea { anchors.fill: parent; onClicked: Ui.close() }

		Box {
			width: tiles.width + Theme.pad * 2
			height: content.implicitHeight + Theme.pad * 2
			anchors.centerIn: parent

			MouseArea { anchors.fill: parent }

			Item {
				id: keys
				anchors.fill: parent
				focus: true
				Keys.onPressed: function (ev) {
					if (ev.key === Qt.Key_Escape) Ui.close();
					else if (ev.key === Qt.Key_Right || ev.key === Qt.Key_Tab) win.move(1);
					else if (ev.key === Qt.Key_Left || ev.key === Qt.Key_Backtab) win.move(-1);
					else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter || ev.key === Qt.Key_Space) win.activate(win.sel);
					else if (ev.text.length === 1 && win.activateKey(ev.text.toUpperCase())) { }
					else return;
					ev.accepted = true;
				}
			}

			Column {
				id: content
				x: Theme.pad
				y: Theme.pad
				spacing: Theme.pad

				Row {
					id: tiles
					spacing: Theme.spacing

					Repeater {
						model: win.actions

						delegate: Item {
							id: tile
							required property var modelData
							required property int index
							readonly property bool armed: win.armed === modelData.id
							readonly property bool selected: win.sel === index
							width: 110
							height: 110

							Rectangle {
								anchors.fill: parent
								radius: Theme.roundingSmall
								color: tile.selected || mouse.containsMouse ? Theme.surfaceTop : Theme.surfaceHi
								border.width: tile.armed || tile.selected ? Math.max(Theme.border, 1) : Theme.border
								border.color: tile.armed ? Theme.error : tile.selected ? Theme.primary : Theme.outlineDim
								Behavior on color { ColorAnimation { duration: Theme.animFast } }
							}

							Txt {
								text: tile.modelData.key
								size: Theme.fontSmall
								muted: true
								anchors.top: parent.top
								anchors.right: parent.right
								anchors.margins: 6
							}

							Column {
								anchors.centerIn: parent
								spacing: Theme.spacing
								Icon {
									glyph: tile.modelData.icon
									size: 36
									color: tile.armed ? Theme.error : tile.selected ? Theme.primary : Theme.fg
									anchors.horizontalCenter: parent.horizontalCenter
								}
								Txt {
									text: tile.armed ? "Confirm?" : tile.modelData.label
									color: tile.armed ? Theme.error : Theme.fg
									anchors.horizontalCenter: parent.horizontalCenter
								}
							}

							MouseArea {
								id: mouse
								anchors.fill: parent
								hoverEnabled: true
								cursorShape: Qt.PointingHandCursor
								onClicked: win.activate(tile.index)
							}
						}
					}
				}

				Txt {
					width: tiles.width
					horizontalAlignment: Text.AlignHCenter
					size: Theme.fontSmall
					muted: true
					text: (win.up === "" ? "" : win.up + " · ") + Quickshell.env("USER") + "@" + win.hostName
				}
			}
		}
	}
}
