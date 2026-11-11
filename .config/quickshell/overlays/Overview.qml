import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.widgets

// Window overview overlay (Ui.overlay === "overview").
// Workspaces of the overlay screen's monitor as panels of live window thumbnails.
// Keys: arrows/WASD/hjkl move, Tab/Shift+Tab switch workspace, 1-9 jump, Enter/Space focus,
// X/Delete close window, Esc/Q leave. Mouse: hover focuses, click activates, middle closes, wheel steps.
// Opened with `qs ipc call shell overlay overview`. Drag-and-drop between workspaces is not implemented.
Scope {
	LazyLoader {
		active: Ui.overlay === "overview"

		PanelWindow {
			id: win
			screen: Ui.overlayScreen
			WlrLayershell.layer: WlrLayer.Overlay
			WlrLayershell.namespace: "qs-overview"
			WlrLayershell.keyboardFocus: Ui.testMode ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
			exclusionMode: ExclusionMode.Ignore
			anchors { top: true; bottom: true; left: true; right: true }
			color: "transparent"

			// [{ id, ws, wins: [HyprlandToplevel] }] for the monitor; replaced only when its content changes.
			property var layout: []
			property string layoutKey: ""
			property int fw: 0            // focused workspace index
			property int fi: 0            // focused window index (-1 on an empty workspace)
			property point lastHover: Qt.point(-100, -100)
			readonly property int total: layout.reduce((n, w) => n + w.wins.length, 0)
			readonly property bool liveThumbs: total <= 12
			readonly property var focusedWin: layout[fw] && fi >= 0 ? layout[fw].wins[fi] || null : null

			function colsFor(n) { return n <= 1 ? 1 : n <= 4 ? 2 : 3; }

			function rebuild() {
				var mon = Windows.monitorFor(win.screen);
				if (!mon) return;
				var ids = Windows.persistentFor(mon.name).slice();
				Hyprland.workspaces.values.forEach(ws => {
					if (ws.id > 0 && ws.monitor && ws.monitor.name === mon.name && ids.indexOf(ws.id) < 0 && Windows.windowsOn(ws.id).length > 0) ids.push(ws.id);
				});
				ids = ids.filter(i => i > 0).sort((a, b) => a - b);
				var out = ids.map(id => ({
					id: id,
					ws: Hyprland.workspaces.values.find(w => w.id === id) || null,
					wins: Windows.windowsOn(id).filter(t => t.wayland)
				}));
				var key = out.map(w => w.id + ":" + w.wins.map(t => t.address).join(",")).join("|");
				if (key === layoutKey) return;
				var cur = focusedWin ? focusedWin.address : "";
				layoutKey = key;
				layout = out;
				if (cur !== "") {
					for (var a = 0; a < out.length; a++) {
						var b = out[a].wins.findIndex(t => t.address === cur);
						if (b >= 0) { fw = a; fi = b; return; }
					}
				}
				clampFocus();
			}

			function clampFocus() {
				if (layout.length === 0) { fw = 0; fi = -1; return; }
				fw = Math.max(0, Math.min(fw, layout.length - 1));
				var n = layout[fw].wins.length;
				fi = n === 0 ? -1 : Math.max(0, Math.min(fi, n - 1));
			}

			function focusActive() {
				for (var a = 0; a < layout.length; a++) {
					var b = layout[a].wins.findIndex(t => t.activated);
					if (b >= 0) { fw = a; fi = b; return; }
				}
				var mon = Windows.monitorFor(win.screen);
				var aw = mon ? mon.activeWorkspace : null;
				var wi = aw ? layout.findIndex(w => w.id === aw.id) : -1;
				fw = Math.max(0, wi);
				fi = layout.length > 0 && layout[fw].wins.length > 0 ? 0 : -1;
			}

			function setFocus(w, i) { fw = w; fi = i; }

			// Left/right across the flat window order, skipping empty workspaces.
			function stepFlat(d) {
				var flat = [];
				layout.forEach((w, a) => w.wins.forEach((t, b) => flat.push([a, b])));
				if (flat.length === 0) return;
				var cur = flat.findIndex(p => p[0] === fw && p[1] === fi);
				if (cur < 0) {
					// Empty workspace: nearest window in direction d.
					var cand = flat.filter(p => d > 0 ? p[0] > fw : p[0] < fw);
					var p0 = cand.length === 0 ? flat[d > 0 ? 0 : flat.length - 1] : (d > 0 ? cand[0] : cand[cand.length - 1]);
					setFocus(p0[0], p0[1]);
					return;
				}
				var n = flat[(cur + d + flat.length) % flat.length];
				setFocus(n[0], n[1]);
			}

			function stepWorkspace(d) {
				if (layout.length === 0) return;
				var a = (fw + d + layout.length) % layout.length;
				setFocus(a, layout[a].wins.length > 0 ? 0 : -1);
			}

			function stepRow(d) {
				var w = layout[fw];
				if (!w || fi < 0) { stepWorkspace(d); return; }
				var cols = colsFor(w.wins.length);
				var rows = Math.ceil(w.wins.length / cols);
				if (rows <= 1) { stepWorkspace(d); return; }
				var n = fi + d * cols;
				if (n >= 0 && n < w.wins.length) fi = n;
				else if (d > 0 && Math.floor(fi / cols) < rows - 1) fi = w.wins.length - 1;
			}

			function jump(n) {
				if (n - 1 >= layout.length) return;
				setFocus(n - 1, layout[n - 1].wins.length > 0 ? 0 : -1);
			}

			function activate() {
				if (focusedWin) focusedWin.wayland.activate();
				else if (layout[fw] && layout[fw].ws) layout[fw].ws.activate();
				else if (layout[fw]) Hyprland.dispatch("workspace " + layout[fw].id);
				Ui.close();
			}

			function closeFocused() {
				if (focusedWin) focusedWin.wayland.close();
			}

			Component.onCompleted: { rebuild(); focusActive(); keys.forceActiveFocus(); }

			Connections {
				target: Windows
				function onRevChanged() { win.rebuild(); }
			}

			MouseArea {
				anchors.fill: parent
				onClicked: Ui.close()
				onWheel: function (w) { win.stepFlat(w.angleDelta.y > 0 ? -1 : 1); }
			}

			Rectangle {
				anchors.fill: parent
				color: Theme.alpha(Theme.bg, 0.93)
				z: -1
			}

			Item {
				id: keys
				anchors.fill: parent
				focus: true
				Keys.onPressed: function (ev) {
					var k = ev.key;
					var shift = (ev.modifiers & Qt.ShiftModifier) !== 0;
					var handled = true;
					if (k === Qt.Key_Escape || k === Qt.Key_Q) Ui.close();
					else if (k === Qt.Key_Right || k === Qt.Key_D || k === Qt.Key_L) win.stepFlat(1);
					else if (k === Qt.Key_Left || k === Qt.Key_A || k === Qt.Key_H) win.stepFlat(-1);
					else if (k === Qt.Key_Down || k === Qt.Key_S || k === Qt.Key_J) win.stepRow(1);
					else if (k === Qt.Key_Up || k === Qt.Key_W || k === Qt.Key_K) win.stepRow(-1);
					else if (k === Qt.Key_Backtab || (k === Qt.Key_Tab && shift)) win.stepWorkspace(-1);
					else if (k === Qt.Key_Tab) win.stepWorkspace(1);
					else if (k >= Qt.Key_1 && k <= Qt.Key_9) win.jump(k - Qt.Key_0);
					else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) win.activate();
					else if (k === Qt.Key_X || k === Qt.Key_Delete) win.closeFocused();
					else handled = false;
					ev.accepted = handled;
				}
			}

			Txt {
				visible: win.layout.length === 0
				anchors.centerIn: parent
				text: "No workspaces"
				muted: true
			}

			Row {
				id: row
				anchors.centerIn: parent
				spacing: Theme.gap * 2
				readonly property int n: Math.max(1, win.layout.length)
				readonly property real panelW: Math.min(460, (win.width - Theme.pad * 4 - spacing * (n - 1)) / n)

				Repeater {
					model: win.layout

					Rectangle {
						id: panel
						required property var modelData
						required property int index
						readonly property bool current: win.fw === index
						readonly property bool isActive: modelData.ws ? (modelData.ws.active || modelData.ws.focused) : false
						readonly property int cols: win.colsFor(modelData.wins.length)
						readonly property real cardW: (width - Theme.pad * 2 - Theme.spacing * (cols - 1)) / cols
						readonly property real cardH: Math.round(cardW * 0.62) + 26

						width: row.panelW
						height: Math.min(win.height - Theme.pad * 4, header.height + Theme.pad * 2 + Math.max(1, Math.ceil(modelData.wins.length / cols)) * (cardH + Theme.spacing))
						radius: Theme.rounding
						color: Theme.surface
						border.width: Theme.border
						border.color: current ? Theme.alpha(Theme.primary, 0.6) : Theme.outlineDim
						Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

						MouseArea { anchors.fill: parent; onClicked: win.setFocus(panel.index, panel.modelData.wins.length > 0 ? Math.max(0, win.fi) : -1) }

						Row {
							id: header
							x: Theme.pad
							y: Theme.pad
							width: parent.width - Theme.pad * 2
							height: 24
							spacing: Theme.spacing
							Txt {
								id: num
								text: String(panel.modelData.id)
								bold: true
								size: Theme.fontLarge
								color: panel.isActive ? Theme.primary : Theme.fg
							}
							Txt {
								width: parent.width - num.width - Theme.spacing
								horizontalAlignment: Text.AlignRight
								text: panel.modelData.wins.length === 1 ? "1 window" : panel.modelData.wins.length + " windows"
								size: Theme.fontSmall
								muted: true
							}
						}

						Txt {
							visible: panel.modelData.wins.length === 0
							anchors.centerIn: parent
							text: "empty"
							muted: true
						}

						Grid {
							x: Theme.pad
							y: Theme.pad + header.height + Theme.spacing
							columns: panel.cols
							spacing: Theme.spacing

							Repeater {
								model: panel.modelData.wins

								Rectangle {
									id: card
									required property var modelData
									required property int index
									readonly property bool focused: win.fw === panel.index && win.fi === index
									readonly property bool hovered: cardMouse.containsMouse
									readonly property bool urgent: modelData.urgent

									width: panel.cardW
									height: panel.cardH
									radius: Theme.roundingSmall
									color: hovered || focused ? Theme.surfaceHi : Theme.surfaceTop
									border.width: focused ? 2 : 1
									border.color: focused ? Theme.primary : urgent ? Theme.warn : hovered ? Theme.outline : Theme.outlineDim
									Behavior on color { ColorAnimation { duration: Theme.animFast } }
									Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

									// Thumbnail area above the title bar.
									Item {
										id: thumb
										x: 4
										y: 4
										width: parent.width - 8
										height: parent.height - 26 - 4
										clip: true

										ScreencopyView {
											id: sc
											anchors.centerIn: parent
											captureSource: card.modelData.wayland
											live: win.liveThumbs
											paintCursor: false
											readonly property real ratio: sourceSize.width > 0 && sourceSize.height > 0 ? sourceSize.width / sourceSize.height : 1.6
											width: Math.min(thumb.width, thumb.height * ratio)
											height: width / ratio
											opacity: hasContent ? 1 : 0
											Component.onCompleted: if (!live) captureFrame()
										}

										Column {
											visible: !sc.hasContent
											anchors.centerIn: parent
											spacing: Theme.spacing
											AppIcon { anchors.horizontalCenter: parent.horizontalCenter; app: Windows.classOf(card.modelData); size: 32 }
											Txt {
												width: thumb.width - 8
												horizontalAlignment: Text.AlignHCenter
												text: Windows.classOf(card.modelData)
												size: Theme.fontSmall
												muted: true
											}
										}
									}

									Row {
										x: 6
										y: parent.height - 24
										width: parent.width - 12
										height: 22
										spacing: Theme.spacing
										AppIcon { anchors.verticalCenter: parent.verticalCenter; app: Windows.classOf(card.modelData); size: 14 }
										Txt {
											width: parent.width - 14 - 20 - Theme.spacing * 2
											anchors.verticalCenter: parent.verticalCenter
											text: card.modelData.title
											size: Theme.fontSmall
											dim: !card.focused
										}
										Rectangle {
											width: 20
											height: 20
											anchors.verticalCenter: parent.verticalCenter
											radius: Theme.roundingSmall
											color: closeMouse.containsMouse ? Theme.alpha(Theme.error, 0.25) : "transparent"
											Behavior on color { ColorAnimation { duration: Theme.animFast } }
											Icon {
												anchors.centerIn: parent
												glyph: Icons.close
												size: 11
												color: closeMouse.containsMouse ? Theme.error : Theme.fgMuted
											}
											MouseArea {
												id: closeMouse
												anchors.fill: parent
												hoverEnabled: true
												cursorShape: Qt.PointingHandCursor
												onClicked: card.modelData.wayland.close()
											}
										}
									}

									MouseArea {
										id: cardMouse
										anchors.fill: parent
										z: -1
										hoverEnabled: true
										acceptedButtons: Qt.LeftButton | Qt.MiddleButton
										cursorShape: Qt.PointingHandCursor
										onPositionChanged: function (m) {
											var g = cardMouse.mapToItem(null, m.x, m.y);
											if (Math.abs(g.x - win.lastHover.x) + Math.abs(g.y - win.lastHover.y) < 3) return;
											win.lastHover = Qt.point(g.x, g.y);
											if (!card.focused) win.setFocus(panel.index, card.index);
										}
										onClicked: function (m) {
											win.setFocus(panel.index, card.index);
											if (m.button === Qt.MiddleButton) win.closeFocused();
											else win.activate();
										}
										onWheel: function (w) { win.stepFlat(w.angleDelta.y > 0 ? -1 : 1); }
									}
								}
							}
						}
					}
				}
			}
		}
	}
}
