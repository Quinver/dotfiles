import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Capture overlay (Ui.overlay === "capture") + the recording indicator.
// Rows: mode / action / [Screenshot] [Record] [audio]. While recording, the
// overlay is a single "Stop recording" button. Last choices live in the
// Capture service. Keys: arrows/hjkl/AD move (W is the "window" shortcut, so
// up is K/Up, down is S/J), Enter/Space activate, R/W/F mode, C/V/E action, Esc/Q close.
Scope {
	id: scope
	property point lastHover: Qt.point(-100, -100)

	component Chip: Item {
		id: chip
		property string label: ""
		property string icon: ""
		property bool selected: false
		property bool focused: false
		property bool big: false
		signal activated()
		signal hovered()
		implicitWidth: row.implicitWidth + Theme.pad * (big ? 2.5 : 1.5)
		implicitHeight: big ? Theme.rowHeight + 12 : Theme.rowHeight
		opacity: enabled ? 1 : 0.45

		Rectangle {
			anchors.fill: parent
			radius: Theme.roundingSmall
			color: chip.selected ? Theme.primary : ma.containsMouse || chip.focused ? Theme.surfaceTop : Theme.surfaceHi
			border.width: Theme.border
			border.color: chip.focused ? Theme.primary : Theme.outlineDim
			opacity: chip.selected && ma.containsMouse ? 0.85 : 1
			Behavior on color { ColorAnimation { duration: Theme.animFast } }
		}
		Row {
			id: row
			anchors.centerIn: parent
			spacing: 7
			Icon {
				visible: chip.icon !== ""
				glyph: chip.icon
				color: chip.selected ? Theme.onPrimary : Theme.fg
				anchors.verticalCenter: parent.verticalCenter
			}
			Txt {
				text: chip.label
				color: chip.selected ? Theme.onPrimary : Theme.fg
				anchors.verticalCenter: parent.verticalCenter
			}
		}
		MouseArea {
			id: ma
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onPositionChanged: function (m) {
				var g = ma.mapToItem(null, m.x, m.y);
				if (Math.abs(g.x - scope.lastHover.x) + Math.abs(g.y - scope.lastHover.y) < 3) return;
				scope.lastHover = Qt.point(g.x, g.y);
				chip.hovered();
			}
			onClicked: chip.activated()
		}
	}

	LazyLoader {
		active: Ui.overlay === "capture"

		PanelWindow {
			id: win
			screen: Ui.overlayScreen
			WlrLayershell.layer: WlrLayer.Overlay
			WlrLayershell.namespace: "qs-capture"
			WlrLayershell.keyboardFocus: Ui.testMode ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
			exclusionMode: ExclusionMode.Ignore
			anchors { top: true; bottom: true; left: true; right: true }
			color: "transparent"

			readonly property var modes: [
				{ id: "region", label: "Region" }, { id: "window", label: "Window" },
				{ id: "screen", label: "Screen" }, { id: "all", label: "All" } ]
			readonly property var actions: [
				{ id: "copy", label: "Copy" }, { id: "save", label: "Save" }, { id: "edit", label: "Edit" } ]
			readonly property bool canRecord: Capture.mode === "region" || Capture.mode === "screen"
			readonly property var rowSizes: [4, 3, 3]

			property int row: 0
			property int col: 0

			function focusAt(r, c) { row = r; col = c; }

			function go(dr, dc) {
				if (dr !== 0) {
					row = (row + dr + 3) % 3;
					col = Math.min(col, rowSizes[row] - 1);
				} else {
					col = (col + dc + rowSizes[row]) % rowSizes[row];
				}
			}

			function doShot() { Capture.shot(Capture.mode, Capture.action); }
			function doRecord() {
				if (canRecord) Capture.startRecord(Capture.mode, Capture.audio);
			}

			function activate() {
				if (Capture.recording) { Capture.stopRecord(); Ui.close(); return; }
				if (row === 0) Capture.mode = modes[col].id;
				else if (row === 1) Capture.action = actions[col].id;
				else if (col === 0) doShot();
				else if (col === 1) doRecord();
				else Capture.audio = !Capture.audio;
			}

			function key(ev) {
				var k = ev.key, t = ev.text.toLowerCase();
				if (k === Qt.Key_Escape || t === "q") { Ui.close(); return true; }
				if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) { activate(); return true; }
				if (Capture.recording) return false;
				if (k === Qt.Key_Left || t === "a" || t === "h") go(0, -1);
				else if (k === Qt.Key_Right || t === "d" || t === "l") go(0, 1);
				else if (k === Qt.Key_Up || t === "k") go(-1, 0);
				else if (k === Qt.Key_Down || t === "s" || t === "j") go(1, 0);
				else if (t === "r") Capture.mode = "region";
				else if (t === "w") Capture.mode = "window";
				else if (t === "f") Capture.mode = "screen";
				else if (t === "c") Capture.action = "copy";
				else if (t === "v") Capture.action = "save";
				else if (t === "e") Capture.action = "edit";
				else return false;
				return true;
			}

			Component.onCompleted: { keys.forceActiveFocus(); if (!Capture.recording) focusAt(2, 0); }
			onVisibleChanged: if (visible) keys.forceActiveFocus()
			onWindowConnected: keys.forceActiveFocus()

			MouseArea { anchors.fill: parent; onClicked: Ui.close() }

			Box {
				anchors.horizontalCenter: parent.horizontalCenter
				anchors.bottom: parent.bottom
				anchors.bottomMargin: parent.height * 0.12
				width: content.implicitWidth + Theme.pad * 2
				height: content.implicitHeight + Theme.pad * 2

				MouseArea { anchors.fill: parent }

				Item {
					id: keys
					anchors.fill: parent
					focus: true
					Keys.onPressed: function (ev) { ev.accepted = win.key(ev); }
				}

				Column {
					id: content
					x: Theme.pad
					y: Theme.pad
					spacing: Theme.spacing + 2

					// Recording: one Stop button.
					Chip {
						visible: Capture.recording
						big: true
						focused: true
						selected: true
						icon: Icons.film
						label: "Stop recording · " + Capture.fmt(Capture.elapsed)
						onActivated: win.activate()
					}

					Column {
						visible: !Capture.recording
						spacing: Theme.spacing + 2

						Row {
							spacing: Theme.spacing
							Repeater {
								model: win.modes
								delegate: Chip {
									required property var modelData
									required property int index
									label: modelData.label
									selected: Capture.mode === modelData.id
									focused: win.row === 0 && win.col === index
									onHovered: win.focusAt(0, index)
									onActivated: { win.focusAt(0, index); win.activate(); }
								}
							}
						}
						Row {
							spacing: Theme.spacing
							Repeater {
								model: win.actions
								delegate: Chip {
									required property var modelData
									required property int index
									label: modelData.label
									selected: Capture.action === modelData.id
									focused: win.row === 1 && win.col === index
									onHovered: win.focusAt(1, index)
									onActivated: { win.focusAt(1, index); win.activate(); }
								}
							}
						}
						Row {
							spacing: Theme.spacing
							Chip {
								big: true
								icon: Icons.camera
								label: "Screenshot"
								focused: win.row === 2 && win.col === 0
								onHovered: win.focusAt(2, 0)
								onActivated: { win.focusAt(2, 0); win.activate(); }
							}
							Chip {
								big: true
								enabled: win.canRecord
								icon: Icons.film
								label: "Record"
								focused: win.row === 2 && win.col === 1
								onHovered: win.focusAt(2, 1)
								onActivated: { win.focusAt(2, 1); win.activate(); }
							}
							Row {
								spacing: Theme.spacing
								anchors.verticalCenter: parent.verticalCenter
								opacity: win.canRecord ? 1 : 0.45
								Toggle {
									checked: Capture.audio
									enabled: win.canRecord
									anchors.verticalCenter: parent.verticalCenter
									onToggled: function (v) { win.focusAt(2, 2); Capture.audio = v; }
								}
								Txt {
									text: "with audio"
									dim: true
									anchors.verticalCenter: parent.verticalCenter
									color: win.row === 2 && win.col === 2 ? Theme.primary : Theme.fgDim
								}
							}
						}
						Txt {
							text: win.canRecord ? "Enter activates · Esc closes" : "Recording supports Region and Screen only"
							size: Theme.fontSmall
							muted: true
						}
					}
				}
			}
		}
	}

	// Recording indicator: small corner window on the recorded screen.
	LazyLoader {
		active: Capture.recording

		PanelWindow {
			id: ind
			screen: {
				var l = Quickshell.screens;
				for (var i = 0; i < l.length; i++) if (l[i].name === Capture.recScreen) return l[i];
				return Ui.overlayScreen;
			}
			WlrLayershell.layer: WlrLayer.Overlay
			WlrLayershell.namespace: "qs-capture-indicator"
			WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
			exclusionMode: ExclusionMode.Ignore
			anchors { top: true; right: true }
			margins { top: Theme.barHeight + Theme.pad; right: Theme.pad }
			implicitWidth: pill.width
			implicitHeight: pill.height
			color: "transparent"

			Rectangle {
				id: pill
				width: irow.implicitWidth + Theme.pad * 2
				height: Theme.rowHeight
				radius: Theme.roundingSmall
				color: stopMa.containsMouse ? Theme.surfaceTop : Theme.surface
				border.width: Theme.border
				border.color: Theme.error
				Behavior on color { ColorAnimation { duration: Theme.animFast } }

				Row {
					id: irow
					anchors.centerIn: parent
					spacing: Theme.spacing + 2
					Rectangle {
						width: 10
						height: 10
						radius: Math.min(2, Theme.roundingSmall)
						color: Theme.error
						anchors.verticalCenter: parent.verticalCenter
						SequentialAnimation on opacity {
							running: Capture.recording
							loops: Animation.Infinite
							NumberAnimation { to: 0.35; duration: 700 }
							NumberAnimation { to: 1; duration: 700 }
						}
					}
					Txt {
						text: "REC " + Capture.fmt(Capture.elapsed)
						mono: true
						anchors.verticalCenter: parent.verticalCenter
					}
					Txt {
						text: "Stop"
						color: Theme.error
						anchors.verticalCenter: parent.verticalCenter
					}
				}
				MouseArea {
					id: stopMa
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onClicked: Capture.stopRecord()
				}
			}
		}
	}
}
