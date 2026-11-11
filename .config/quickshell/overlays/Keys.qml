import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Keybind cheatsheet overlay (Ui.overlay === "keys"), opened with
// `qs ipc call shell overlay keys`. Shows every bind parsed live from the Hyprland
// Lua keybinds file (services/Keybinds.qml), grouped by section in balanced columns.
// Typing filters (all words must match key, mods or description); Esc clears the
// search, then closes; Up/Down/PageUp/PageDown and the wheel scroll.
Scope {
	LazyLoader {
		active: Ui.overlay === "keys"

		PanelWindow {
			id: win
			screen: Ui.overlayScreen
			WlrLayershell.layer: WlrLayer.Overlay
			WlrLayershell.namespace: "qs-keys"
			WlrLayershell.keyboardFocus: Ui.testMode ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
			exclusionMode: ExclusionMode.Ignore
			anchors { top: true; bottom: true; left: true; right: true }
			color: Theme.alpha(Theme.bg, 0.6)

			property string query: ""
			readonly property int colCount: panel.width > 1250 ? 3 : panel.width > 820 ? 2 : 1
			readonly property int rowH: 28

			function matches(b, words) {
				var hay = (b.mods.join(" ") + " " + b.key + " " + b.desc).toLowerCase();
				for (var i = 0; i < words.length; i++) if (hay.indexOf(words[i]) < 0) return false;
				return true;
			}

			// Filtered sections, then spread over colCount columns, each section going
			// to the currently shortest column (weight = rows + header).
			readonly property var columns: {
				var words = query.toLowerCase().split(/[\s+]+/).filter(w => w !== "");
				var cols = [], heights = [];
				for (var c = 0; c < colCount; c++) { cols.push([]); heights.push(0); }
				var secs = Keybinds.sections;
				for (var i = 0; i < secs.length; i++) {
					var list = secs[i].binds.filter(b => matches(b, words));
					if (!list.length) continue;
					var k = heights.indexOf(Math.min.apply(null, heights));
					cols[k].push({ name: secs[i].name, binds: list });
					heights[k] += list.length + 2;
				}
				return cols;
			}
			readonly property bool empty: columns.every(c => c.length === 0)

			function scrollBy(dy) {
				var max = Math.max(0, flick.contentHeight - flick.height);
				flick.contentY = Math.max(0, Math.min(max, flick.contentY + dy));
			}

			MouseArea { anchors.fill: parent; onClicked: Ui.close() }

			Box {
				id: panel
				width: Math.min(1500, win.width * 0.9)
				height: Math.min(900, win.height * 0.88)
				anchors.centerIn: parent

				MouseArea { anchors.fill: parent }

				Item {
					anchors.fill: parent
					anchors.margins: Theme.pad
					focus: true
					Component.onCompleted: search.focusInput()

					Keys.onPressed: function (ev) {
						var k = ev.key;
						ev.accepted = true;
						if (k === Qt.Key_Escape) {
							if (win.query !== "") { search.text = ""; win.query = ""; }
							else Ui.close();
						} else if (k === Qt.Key_Down) win.scrollBy(win.rowH * 2);
						else if (k === Qt.Key_Up) win.scrollBy(-win.rowH * 2);
						else if (k === Qt.Key_PageDown) win.scrollBy(flick.height * 0.9);
						else if (k === Qt.Key_PageUp) win.scrollBy(-flick.height * 0.9);
						else ev.accepted = false;
					}

					Txt {
						id: title
						anchors.left: parent.left
						anchors.verticalCenter: search.verticalCenter
						size: Theme.fontLarge
						bold: true
						text: "Keybinds"
					}

					Field {
						id: search
						anchors.top: parent.top
						anchors.left: title.right
						anchors.leftMargin: Theme.pad * 2
						anchors.right: parent.right
						icon: Icons.search
						placeholder: "search keys, modifiers, actions"
						onEdited: function (t) { win.query = t; flick.contentY = 0; }
					}

					Flickable {
						id: flick
						anchors.top: search.bottom
						anchors.topMargin: Theme.pad
						anchors.bottom: footer.top
						anchors.bottomMargin: Theme.pad
						anchors.left: parent.left
						anchors.right: parent.right
						clip: true
						contentWidth: width
						contentHeight: colRow.height
						boundsBehavior: Flickable.StopAtBounds

						Row {
							id: colRow
							width: flick.width
							spacing: Theme.pad * 2

							Repeater {
								model: win.columns

								Column {
									id: col
									required property var modelData
									width: (colRow.width - colRow.spacing * (win.colCount - 1)) / win.colCount
									spacing: Theme.pad

									Repeater {
										model: col.modelData

										Column {
											id: sec
											required property var modelData
											width: col.width

											Header { width: parent.width; title: sec.modelData.name }
											Sep { width: parent.width }
											Item { width: 1; height: 4 }

											Repeater {
												model: sec.modelData.binds

												Rectangle {
													id: row
													required property var modelData
													width: sec.width
													height: win.rowH
													radius: Theme.roundingSmall
													color: rowMouse.containsMouse ? Theme.surfaceHi : "transparent"
													Behavior on color { ColorAnimation { duration: Theme.animFast } }

													Row {
														id: caps
														x: 4
														anchors.verticalCenter: parent.verticalCenter
														spacing: 4

														Repeater {
															model: row.modelData.mods.concat([row.modelData.key])

															Box {
																id: cap
																required property string modelData
																readonly property bool isSuper: modelData === "SUPER"
																level: 2
																small: true
																anchors.verticalCenter: parent.verticalCenter
																width: Math.max(capText.implicitWidth, capIcon.implicitWidth) + 12
																height: win.rowH - 8
																color: rowMouse.containsMouse ? Theme.surfaceTop : Theme.surfaceHi

																Txt {
																	id: capText
																	anchors.centerIn: parent
																	visible: !cap.isSuper
																	text: cap.modelData
																	size: Theme.fontSmall
																	mono: true
																}
																Icon {
																	id: capIcon
																	anchors.centerIn: parent
																	visible: cap.isSuper
																	glyph: Icons.desktop
																	size: Theme.fontSmall
																	color: Theme.primary
																}
															}
														}
													}

													Txt {
														anchors.left: parent.left
														anchors.leftMargin: sec.width * 0.42
														anchors.right: parent.right
														anchors.rightMargin: 4
														anchors.verticalCenter: parent.verticalCenter
														text: row.modelData.desc
														dim: true
														color: rowMouse.containsMouse ? Theme.fg : Theme.fgDim
													}

													MouseArea {
														id: rowMouse
														anchors.fill: parent
														hoverEnabled: true
														acceptedButtons: Qt.NoButton
													}
												}
											}
										}
									}
								}
							}
						}
					}

					Txt {
						anchors.centerIn: flick
						visible: win.empty
						muted: true
						text: "no binds match"
					}

					Txt {
						id: footer
						anchors.left: parent.left
						anchors.right: parent.right
						anchors.bottom: parent.bottom
						size: Theme.fontSmall
						muted: true
						horizontalAlignment: Text.AlignHCenter
						text: "Super binds also work with Ctrl+Alt (except those using Ctrl) · type to search · ↑↓ scroll · Esc clear / close"
					}
				}
			}
		}
	}
}
