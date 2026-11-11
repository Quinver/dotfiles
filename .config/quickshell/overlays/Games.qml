import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Games overlay (Ui.overlay === "games"): one searchable cover grid of every
// installed Steam / Faugus / Prism game, plus a Steam account switcher.
//   Arrows or WASD/hjkl move, Enter launches, Tab cycles the source filter,
//   Esc clears the search (then closes), Q closes.
//   "/" or any other letter starts typing a search; WASD/hjkl/q are commands
//   only while the search is empty and not in typing mode.
LazyLoader {
	active: Ui.overlay === "games"

	PanelWindow {
		id: win
		screen: Ui.overlayScreen
		WlrLayershell.layer: WlrLayer.Overlay
		WlrLayershell.namespace: "qs-games"
		WlrLayershell.keyboardFocus: Ui.testMode ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
		exclusionMode: ExclusionMode.Ignore
		anchors { top: true; bottom: true; left: true; right: true }
		color: Qt.rgba(0, 0, 0, 0.55)

		readonly property var sources: ["all", "steam", "faugus", "prism"]
		readonly property var sourceLabels: ({ all: "All", steam: "Steam", faugus: "Faugus", prism: "Prism" })
		readonly property var sortModes: ["recent", "name", "playtime"]
		property string source: "all"
		property string sortMode: "recent"
		property bool typing: false
		property int sel: 0
		property string armed: ""            // account awaiting a second confirmation
		readonly property string query: field.text.trim().toLowerCase()

		readonly property var shown: {
			var list = Games.games.filter(g => (source === "all" || g.source === source)
				&& (query === "" || g.name.toLowerCase().indexOf(query) >= 0));
			var m = sortMode;
			list.sort((a, b) => m === "name" ? a.name.localeCompare(b.name)
				: m === "playtime" ? (b.playMinutes - a.playMinutes) || a.name.localeCompare(b.name)
				: (b.lastPlayed - a.lastPlayed) || a.name.localeCompare(b.name));
			return list;
		}
		onShownChanged: sel = Math.min(sel, Math.max(0, shown.length - 1))

		function fmtTime(min) {
			if (min <= 0) return "Not played";
			if (min < 60) return min + " min";
			var h = min / 60;
			return (h < 10 ? h.toFixed(1) : Math.round(h)) + " h";
		}

		function cycleSource(d) {
			source = sources[(sources.indexOf(source) + d + sources.length) % sources.length];
			sel = 0;
		}

		function move(dx, dy) {
			if (shown.length === 0) return;
			var cols = grid.cols;
			var n = sel + dx + dy * cols;
			if (dy !== 0 && (n < 0 || n >= shown.length)) return;
			sel = Math.max(0, Math.min(shown.length - 1, n));
			grid.positionViewAtIndex(sel, GridView.Contain);
		}

		function activate(i) {
			var g = shown[i];
			if (!g) return;
			Games.launch(g);
			Ui.close();
		}

		function pickAccount(a) {
			if (a.current || a.account === "") return;
			if (armed === a.account) { armed = ""; Games.switchAccount(a.account); Ui.close(); }
			else { armed = a.account; armTimer.restart(); }
		}

		function focusField() { field.focusInput(); }
		Component.onCompleted: { Games.refresh(); focusField(); }
		onVisibleChanged: if (visible) focusField()
		onWindowConnected: focusField()

		Timer { id: armTimer; interval: 3000; onTriggered: win.armed = "" }

		MouseArea { anchors.fill: parent; onClicked: Ui.close() }

		Box {
			id: panel
			width: Math.min(parent.width - Theme.pad * 4, 1280)
			height: Math.min(parent.height - Theme.pad * 4, 900)
			anchors.centerIn: parent

			MouseArea { anchors.fill: parent }

			Column {
				id: top
				x: Theme.pad
				y: Theme.pad
				width: parent.width - Theme.pad * 2
				spacing: Theme.spacing

				Row {
					width: parent.width
					spacing: Theme.spacing

					Field {
						id: field
						width: parent.width - sortRow.width - Theme.spacing
						icon: Icons.search
						placeholder: "Search games   (/ to type)"
						onEdited: { win.sel = 0; win.typing = true; }
						onAccepted: win.activate(win.sel)

						input.Keys.onPressed: function (ev) {
							var plain = !(ev.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier));
							var navMode = !win.typing && field.text === "";
							var t = ev.text;
							if (ev.key === Qt.Key_Escape) {
								if (field.text !== "" || win.typing) { field.text = ""; win.typing = false; win.sel = 0; }
								else Ui.close();
							} else if (ev.key === Qt.Key_Tab) win.cycleSource(1);
							else if (ev.key === Qt.Key_Backtab) win.cycleSource(-1);
							else if (ev.key === Qt.Key_Down) win.move(0, 1);
							else if (ev.key === Qt.Key_Up) win.move(0, -1);
							else if (ev.key === Qt.Key_Right && field.text === "") win.move(1, 0);
							else if (ev.key === Qt.Key_Left && field.text === "") win.move(-1, 0);
							else if (navMode && plain && (t === "/" )) win.typing = true;
							else if (navMode && plain && (t === "a" || t === "h")) win.move(-1, 0);
							else if (navMode && plain && (t === "d" || t === "l")) win.move(1, 0);
							else if (navMode && plain && (t === "w" || t === "k")) win.move(0, -1);
							else if (navMode && plain && (t === "s" || t === "j")) win.move(0, 1);
							else if (navMode && plain && t === "q") Ui.close();
							else return;
							ev.accepted = true;
						}
					}

					Row {
						id: sortRow
						spacing: 4
						Repeater {
							model: win.sortModes
							Btn {
								required property string modelData
								text: modelData === "recent" ? "Recent" : modelData === "name" ? "Name" : "Playtime"
								checked: win.sortMode === modelData
								onClicked: { win.sortMode = modelData; win.sel = 0; }
							}
						}
					}
				}

				Row {
					width: parent.width
					spacing: Theme.spacing

					Row {
						id: chips
						spacing: 4
						Repeater {
							model: win.sources
							Btn {
								required property string modelData
								text: win.sourceLabels[modelData]
								checked: win.source === modelData
								onClicked: { win.source = modelData; win.sel = 0; }
							}
						}
					}

					Item { width: Math.max(0, parent.width - chips.width - accts.width - Theme.spacing * 2); height: 1 }

					Row {
						id: accts
						spacing: 4
						Icon {
							visible: Games.accounts.length > 0
							glyph: Icons.user
							color: Theme.fgMuted
							anchors.verticalCenter: parent.verticalCenter
						}
						Repeater {
							model: Games.accounts
							Btn {
								required property var modelData
								readonly property bool armedNow: win.armed === modelData.account && modelData.account !== ""
								text: armedNow ? "Restart Steam as " + modelData.persona + "?"
									: modelData.persona + (modelData.account === "" || !modelData.remembered ? "  (login needed)" : "")
								checked: modelData.current
								danger: armedNow
								enabled: modelData.account !== "" || modelData.current
								opacity: modelData.remembered || modelData.current ? 1 : 0.6
								onClicked: win.pickAccount(modelData)
							}
						}
					}
				}

				Sep { width: parent.width }
			}

			GridView {
				id: grid
				anchors.top: top.bottom
				anchors.topMargin: Theme.spacing
				anchors.left: parent.left
				anchors.right: parent.right
				anchors.bottom: hint.top
				anchors.leftMargin: Theme.pad
				anchors.rightMargin: Theme.pad
				clip: true
				boundsBehavior: Flickable.StopAtBounds
				model: win.shown
				currentIndex: win.sel
				readonly property int cols: Math.max(2, Math.floor(width / 190))
				cellWidth: Math.floor(width / cols)
				cellHeight: Math.round((cellWidth - Theme.spacing) * 1.5) + 52

				delegate: Item {
					id: tile
					required property var modelData
					required property int index
					readonly property bool selected: index === win.sel
					readonly property bool hot: hover.hovered
					width: grid.cellWidth
					height: grid.cellHeight

					Item {
						id: card
						anchors.fill: parent
						anchors.margins: Theme.spacing / 2
						scale: tile.hot || tile.selected ? 1.03 : 1
						Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

						Rectangle {
							id: art
							width: parent.width
							height: Math.round(parent.width * 1.5)
							radius: Theme.roundingSmall
							color: Theme.surfaceHi
							clip: true

							Image {
								id: img
								readonly property bool icon: tile.modelData.source === "prism"
								anchors.fill: parent
								anchors.margins: icon ? parent.width * 0.25 : 0
								source: tile.modelData.cover !== "" ? "file://" + tile.modelData.cover : ""
								fillMode: icon ? Image.PreserveAspectFit : Image.PreserveAspectCrop
								smooth: !icon
								asynchronous: true
								sourceSize.width: 400
								visible: status === Image.Ready
							}
							Column {
								visible: img.status !== Image.Ready
								anchors.centerIn: parent
								width: parent.width - Theme.pad * 2
								spacing: Theme.spacing
								Icon {
									anchors.horizontalCenter: parent.horizontalCenter
									glyph: Icons.gamepad
									size: 28
									color: Theme.fgMuted
								}
								Txt {
									width: parent.width
									horizontalAlignment: Text.AlignHCenter
									wrapMode: Text.WordWrap
									maximumLineCount: 3
									dim: true
									text: tile.modelData.name
								}
							}
							Rectangle {
								anchors.fill: parent
								radius: parent.radius
								color: "transparent"
								border.width: tile.selected ? 2 : tile.hot ? 1 : 0
								border.color: tile.selected ? Theme.primary : Theme.fgDim
							}
							Rectangle {
								anchors.top: parent.top
								anchors.right: parent.right
								anchors.margins: 4
								height: srcTxt.implicitHeight + 4
								width: srcTxt.implicitWidth + 10
								radius: Theme.roundingSmall
								color: Theme.alpha(Theme.bg, 0.8)
								Txt {
									id: srcTxt
									anchors.centerIn: parent
									size: Theme.fontSmall
									dim: true
									text: win.sourceLabels[tile.modelData.source]
								}
							}
						}

						Txt {
							anchors.top: art.bottom
							anchors.topMargin: 6
							width: parent.width
							bold: true
							color: tile.selected ? Theme.primary : Theme.fg
							text: tile.modelData.name
						}
						Txt {
							anchors.top: art.bottom
							anchors.topMargin: 6 + 22
							width: parent.width
							size: Theme.fontSmall
							muted: true
							text: win.fmtTime(tile.modelData.playMinutes)
						}
					}

					HoverHandler {
						id: hover
						onPointChanged: if (hovered) win.sel = tile.index
					}
					MouseArea {
						anchors.fill: parent
						onClicked: win.activate(tile.index)
					}
				}
			}

			Txt {
				anchors.centerIn: grid
				visible: win.shown.length === 0
				muted: true
				text: Games.loading && !Games.loaded ? "Loading games..." : "No games found"
			}

			Txt {
				id: hint
				anchors.bottom: parent.bottom
				anchors.bottomMargin: Theme.pad / 2
				anchors.horizontalCenter: parent.horizontalCenter
				height: Theme.rowHeight - 8
				size: Theme.fontSmall
				muted: true
				text: "arrows / wasd / hjkl move  ·  enter launch  ·  tab source  ·  / search  ·  esc close"
			}
		}
	}
}
