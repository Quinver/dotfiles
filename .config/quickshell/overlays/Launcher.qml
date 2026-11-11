import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Application launcher overlay (Ui.overlay === "launcher").
//   <text>   fuzzy-search apps          = <expr>  calculator (Enter copies)
//   > <cmd>  run a shell command        Up/Down, Ctrl+P/N/K/J, Tab: move
LazyLoader {
	// Referencing Apps here instantiates it at startup so the desktop entry
	// list is already filled the first time the launcher opens.
	readonly property int appCount: Apps.all.length
	active: Ui.overlay === "launcher"

	PanelWindow {
		id: win
		screen: Ui.overlayScreen
		WlrLayershell.layer: WlrLayer.Overlay
		WlrLayershell.namespace: "qs-launcher"
		WlrLayershell.keyboardFocus: Ui.testMode ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
		exclusionMode: ExclusionMode.Ignore
		anchors { top: true; bottom: true; left: true; right: true }
		color: Qt.rgba(0, 0, 0, 0.35)

		readonly property int rowH: Theme.rowHeight + 8
		readonly property string query: field.text
		property int sel: 0
		// Last pointer position seen over the list. Hover only changes the
		// selection when the pointer has actually moved, so a cursor that
		// happens to rest where the launcher opens (or where rows shift to
		// while typing) doesn't steal the selection.
		property point lastHover: Qt.point(-1, -1)
		property bool mouseMoved: false

		// Rows: { kind: "app" | "calc" | "cmd", title, subtitle, entry }
		readonly property var rows: {
			var q = query.trim();
			if (q.charAt(0) === ">") {
				var cmd = q.slice(1).trim();
				return cmd === "" ? [] : [{ kind: "cmd", title: "Run: " + cmd, subtitle: "", text: cmd }];
			}
			if (q.charAt(0) === "=") {
				var c = Apps.calc(q);
				return c.ok ? [{ kind: "calc", title: c.text, subtitle: "Enter to copy", text: c.text }] : [];
			}
			var apps = Apps.search(q).slice(0, 50).map(e => ({
				kind: "app", title: e.name, subtitle: e.genericName || e.comment, entry: e
			}));
			if (apps.length === 0 && /[-+*\/^%]/.test(q.replace(/^-/, ""))) {
				var r = Apps.calc(q);
				if (r.ok) return [{ kind: "calc", title: r.text, subtitle: "Enter to copy", text: r.text }];
			}
			return apps;
		}

		function move(d) {
			if (rows.length === 0) return;
			sel = (sel + d + rows.length) % rows.length;
			list.positionViewAtIndex(sel, ListView.Contain);
		}

		function activate(i) {
			var r = rows[i];
			if (!r) return;
			if (r.kind === "app") Apps.launch(r.entry);
			else if (r.kind === "calc") { Quickshell.clipboardText = r.text; Ui.close(); }
			else { Quickshell.execDetached(["sh", "-c", r.text]); Ui.close(); }
		}

		function focusField() { field.focusInput(); }
		Component.onCompleted: focusField()
		onVisibleChanged: if (visible) { lastHover = Qt.point(-1, -1); mouseMoved = false; focusField(); }
		onWindowConnected: focusField()

		MouseArea { anchors.fill: parent; onClicked: Ui.close() }

		Box {
			id: panel
			width: 560
			height: col.implicitHeight + Theme.pad * 2
			anchors.horizontalCenter: parent.horizontalCenter
			y: Math.round(parent.height * 0.22)

			MouseArea { anchors.fill: parent }

			Column {
				id: col
				x: Theme.pad
				y: Theme.pad
				width: parent.width - Theme.pad * 2
				spacing: Theme.spacing

				Field {
					id: field
					width: parent.width
					icon: Icons.search
					placeholder: "Search apps, or = to calculate"
					onEdited: win.sel = 0
					onAccepted: win.activate(win.sel)

					input.Keys.onPressed: function (ev) {
						var ctrl = ev.modifiers & Qt.ControlModifier;
						if (ev.key === Qt.Key_Escape) Ui.close();
						else if (ev.key === Qt.Key_Down || ev.key === Qt.Key_Tab || (ctrl && (ev.key === Qt.Key_N || ev.key === Qt.Key_J))) win.move(1);
						else if (ev.key === Qt.Key_Up || ev.key === Qt.Key_Backtab || (ctrl && (ev.key === Qt.Key_P || ev.key === Qt.Key_K))) win.move(-1);
						else return;
						ev.accepted = true;
					}
				}

				ListView {
					id: list
					width: parent.width
					height: Math.min(count, 8) * win.rowH
					visible: count > 0
					clip: true
					model: win.rows
					currentIndex: win.sel
					boundsBehavior: Flickable.StopAtBounds

					// One handler for the whole list: selection follows the
					// pointer only once it has really moved since opening.
					HoverHandler {
						onPointChanged: {
							if (!hovered) return;
							const p = point.scenePosition;
							const prev = win.lastHover;
							win.lastHover = Qt.point(p.x, p.y);
							if (prev.x < 0 || (prev.x === p.x && prev.y === p.y)) return;
							win.mouseMoved = true;
							const i = list.indexAt(point.position.x + list.contentX, point.position.y + list.contentY);
							if (i >= 0) win.sel = i;
						}
					}

					delegate: Item {
						id: row
						required property var modelData
						required property int index
						readonly property bool isCalc: modelData.kind === "calc"
						width: list.width
						height: win.rowH

						ListItem {
							anchors.fill: parent
							visible: !row.isCalc
							title: row.modelData.title
							subtitle: row.modelData.subtitle
							selected: row.index === win.sel
							hoverHighlight: win.mouseMoved
							onClicked: win.activate(row.index)

							leading: [
								Item {
									width: 24
									height: 24
									AppIcon {
										visible: row.modelData.kind === "app"
										app: row.modelData.kind === "app" ? row.modelData.entry.icon : ""
										size: 24
									}
									Icon {
										visible: row.modelData.kind !== "app"
										anchors.centerIn: parent
										glyph: Icons.terminal
										color: Theme.fgDim
									}
								}
							]
						}

						// Calculator result: big mono number, copy hint below.
						Item {
							anchors.fill: parent
							visible: row.isCalc

							Rectangle {
								anchors.fill: parent
								radius: Theme.roundingSmall
								color: Theme.surfaceTop
							}
							Rectangle { width: 2; height: parent.height; color: Theme.primary }
							Icon {
								id: calcIcon
								glyph: Icons.gauge
								color: Theme.primary
								anchors.left: parent.left
								anchors.leftMargin: Theme.pad
								anchors.verticalCenter: parent.verticalCenter
							}
							Column {
								anchors.left: calcIcon.right
								anchors.leftMargin: Theme.pad
								anchors.right: parent.right
								anchors.rightMargin: Theme.pad
								anchors.verticalCenter: parent.verticalCenter
								Txt { width: parent.width; mono: true; size: Theme.fontLarge; text: row.modelData.title }
								Txt { width: parent.width; size: Theme.fontSmall; muted: true; text: row.modelData.subtitle }
							}
							MouseArea { anchors.fill: parent; onClicked: win.activate(row.index) }
						}

						}
					}
				}

				Txt {
					visible: list.count === 0
					width: parent.width
					height: Theme.rowHeight
					horizontalAlignment: Text.AlignHCenter
					muted: true
					text: "No matches"
				}

				Txt {
					width: parent.width
					size: Theme.fontSmall
					muted: true
					horizontalAlignment: Text.AlignHCenter
					text: "↑↓ navigate · ⏎ launch · = calc · > run · esc close"
				}
			}
		}
	}
}
