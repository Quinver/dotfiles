import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

// Control centre (the burger menu): identity + quick toggles, theme tiles,
// wallpaper preview and rotation, appearance options, settings file shortcut.
// Everything below the top row scrolls.
Column {
	id: root

	// false: appearance controls write to the current theme; true: to the global defaults.
	property bool scopeAll: false
	property string hostname: ""

	width: 400
	spacing: Theme.spacing

	readonly property var themeOptions: Settings.theme.options || ({})
	readonly property bool monoTheme: (Settings.theme.colors || ({})).source === "mono"

	function writeOpt(key, value) {
		if (root.scopeAll) {
			Settings.setOption(key, value);
			// A theme override would hide the global change, so drop it.
			if (root.themeOptions[key] !== undefined) Settings.setThemeOption(key, null);
		} else {
			Settings.setThemeOption(key, value);
		}
	}

	function baseName(path) { return path ? path.split("/").pop() : ""; }

	function describe(name) {
		var src = ((Settings.themes[name] || ({})).colors || ({})).source;
		return src === "wallpaper" ? "Colours from wallpaper" : src === "mono" ? "Monochrome" : "Fixed accent";
	}

	FileView {
		path: "/etc/hostname"
		blockLoading: true
		onLoaded: root.hostname = text().trim()
	}

	// A row of equal-width buttons, one per option; `current` is the selected value.
	component Choice: Item {
		id: ch
		property var options: []       // [{ label, value }]
		property var current
		signal picked(var value)

		function same(a, b) {
			return typeof a === "number" && typeof b === "number" ? Math.abs(a - b) < 0.001 : a === b;
		}

		implicitHeight: Theme.rowHeight
		Row {
			spacing: Theme.spacing
			Repeater {
				model: ch.options
				Btn {
					required property var modelData
					width: (ch.width - (ch.options.length - 1) * Theme.spacing) / ch.options.length
					text: modelData.label
					checked: ch.same(modelData.value, ch.current)
					onClicked: ch.picked(modelData.value)
				}
			}
		}
	}

	// A label on the left with the current value in mono on the right.
	component LabelRow: Item {
		id: lr
		property string label: ""
		property string value: ""
		implicitHeight: 20
		Txt { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: lr.label; dim: true }
		Txt {
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			text: lr.value
			mono: true
			size: Theme.fontSmall
		}
	}

	// Slider that shows a local value while dragging and commits shortly after the last move,
	// so settings.json is not rewritten on every pixel.
	component OptSlider: Item {
		id: os
		property real from: 0
		property real to: 1
		property real stepSize: 1
		property real current: 0
		property real pending: -1
		readonly property real shown: pending >= 0 ? pending : current
		signal commit(real value)

		implicitHeight: 20
		Slider {
			anchors.fill: parent
			value: (os.shown - os.from) / (os.to - os.from)
			onMoved: function (v) {
				os.pending = Math.round((os.from + v * (os.to - os.from)) / os.stepSize) * os.stepSize;
				settle.restart();
			}
		}
		Timer {
			id: settle
			interval: 150
			onTriggered: {
				var v = os.pending;
				os.pending = -1;
				if (v >= 0) os.commit(v);
			}
		}
	}

	// ---- top row ----
	Item {
		width: root.width
		height: Theme.rowHeight

		Txt {
			anchors.left: parent.left
			anchors.right: actions.left
			anchors.rightMargin: Theme.spacing
			anchors.verticalCenter: parent.verticalCenter
			text: Quickshell.env("USER") + (root.hostname ? "@" + root.hostname : "")
			bold: true
			size: Theme.fontLarge
		}
		Row {
			id: actions
			anchors.right: parent.right
			spacing: Theme.spacing / 2
			Btn { flat: true; icon: Icons.eyeSlash; checked: Settings.safeActive; onClicked: Settings.toggleSafe() }
			Btn { flat: true; icon: Icons.bellOff; checked: !!Settings.state.dnd; onClicked: Settings.setState("dnd", !Settings.state.dnd) }
			Btn { flat: true; icon: Icons.power; onClicked: Ui.toggleOverlay("power") }
		}
	}

	Item {
		width: root.width
		height: flick.height

	Flickable {
		id: flick
		width: parent.width
		height: Math.min(contentHeight, 760)
		contentWidth: width
		contentHeight: body.height
		clip: true
		boundsBehavior: Flickable.StopAtBounds

		Column {
			id: body
			width: flick.width - 8
			spacing: Theme.spacing

			// ---- theme ----
			Header { width: body.width; title: "Theme" }
			Grid {
				width: body.width
				columns: 2
				spacing: Theme.spacing
				Repeater {
					model: Settings.themeNames
					Box {
						id: tile
						required property string modelData
						readonly property bool active: Settings.themeName === modelData
						width: (body.width - Theme.spacing) / 2
						height: 74
						level: tileMouse.containsMouse ? 3 : 2
						border.width: active ? 2 : Theme.border
						border.color: active ? Theme.primary : Theme.outlineDim

						Column {
							anchors.fill: parent
							anchors.margins: Theme.pad
							spacing: 2
							Txt { width: parent.width; text: Settings.themeLabel(tile.modelData); bold: true }
							Txt { width: parent.width; text: root.describe(tile.modelData); dim: true; size: Theme.fontSmall }
							Row {
								visible: tile.active
								spacing: 3
								topPadding: 4
								Repeater {
									model: [Theme.bg, Theme.surfaceTop, Theme.primary, Theme.secondary, Theme.tertiary]
									Rectangle {
										required property color modelData
										width: 14
										height: 14
										color: modelData
										border.width: 1
										border.color: Theme.outline
									}
								}
							}
						}
						MouseArea {
							id: tileMouse
							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							onClicked: Settings.setTheme(tile.modelData)
						}
					}
				}
			}

			// ---- wallpaper ----
			Header { width: body.width; title: "Wallpaper" }
			Item {
				width: body.width
				height: Math.round(width * 9 / 16)

				Rectangle { anchors.fill: parent; color: Theme.surfaceHi }
				Image {
					anchors.fill: parent
					source: Wallpapers.url(Wallpapers.current)
					asynchronous: true
					sourceSize.width: 800
					fillMode: Image.PreserveAspectCrop
				}
				Txt {
					visible: Wallpapers.files.length === 0
					anchors.centerIn: parent
					text: Wallpapers.loaded ? "No wallpapers in this theme" : "Loading..."
					muted: true
				}
				Rectangle {
					visible: Wallpapers.files.length > 0
					anchors.left: parent.left
					anchors.right: parent.right
					anchors.bottom: parent.bottom
					height: Theme.rowHeight - 6
					color: Qt.rgba(0, 0, 0, 0.6)
					Txt {
						anchors.left: parent.left
						anchors.right: pos.left
						anchors.leftMargin: Theme.spacing
						anchors.rightMargin: Theme.spacing
						anchors.verticalCenter: parent.verticalCenter
						text: root.baseName(Wallpapers.current)
						color: "white"
						size: Theme.fontSmall
					}
					Txt {
						id: pos
						anchors.right: parent.right
						anchors.rightMargin: Theme.spacing
						anchors.verticalCenter: parent.verticalCenter
						text: (Wallpapers.index + 1) + " / " + Wallpapers.files.length
						color: "white"
						mono: true
						size: Theme.fontSmall
					}
				}
			}
			Row {
				spacing: Theme.spacing
				Btn { icon: Icons.previous; onClicked: Wallpapers.prev() }
				Btn { icon: Icons.next; onClicked: Wallpapers.next() }
				Btn {
					icon: Settings.state.rotatePaused ? Icons.play : Icons.pause
					checked: !!Settings.state.rotatePaused
					onClicked: Wallpapers.togglePause()
				}
				// Ui.popout is set directly (not Ui.toggle) so the picker keeps this panel's
				// screen and anchorX instead of jumping to the default position.
				Btn { icon: Icons.grid; text: "Browse"; onClicked: Ui.popout = "wallpapers" }
			}

			Item {
				width: body.width
				height: 20
				Txt { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Rotate wallpapers"; dim: true }
				Toggle {
					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					checked: Settings.opt("rotate", true)
					onToggled: v => Settings.setThemeOption("rotate", v)
				}
			}
			Choice {
				width: body.width
				current: Settings.opt("rotateInterval", 600)
				options: [{ label: "1m", value: 60 }, { label: "5m", value: 300 }, { label: "10m", value: 600 },
					{ label: "30m", value: 1800 }, { label: "1h", value: 3600 }]
				onPicked: v => Settings.setThemeOption("rotateInterval", v)
			}
			Choice {
				width: body.width
				current: Settings.opt("rotateOrder", "sequential")
				options: [{ label: "Sequential", value: "sequential" }, { label: "Random", value: "random" }]
				onPicked: v => Settings.setThemeOption("rotateOrder", v)
			}

			// ---- appearance ----
			Header { width: body.width; title: "Appearance" }
			Choice {
				width: body.width
				current: root.scopeAll
				options: [{ label: "This theme", value: false }, { label: "All themes", value: true }]
				onPicked: v => root.scopeAll = v
			}

			LabelRow {
				width: body.width
				label: "Rounding"
				value: roundSlider.shown === 0 ? "0 px - sharp" : roundSlider.shown + " px"
			}
			OptSlider {
				id: roundSlider
				width: body.width
				from: 0; to: 20; stepSize: 1
				current: Settings.opt("rounding", 0)
				onCommit: v => root.writeOpt("rounding", v)
			}

			LabelRow { width: body.width; label: "Border width"; value: Settings.opt("border", 1) + " px" }
			Choice {
				width: body.width
				current: Settings.opt("border", 1)
				options: [{ label: "0", value: 0 }, { label: "1", value: 1 }, { label: "2", value: 2 }]
				onPicked: v => root.writeOpt("border", v)
			}

			LabelRow { width: body.width; label: "Bar height"; value: Settings.opt("barHeight", 32) + " px" }
			Choice {
				width: body.width
				current: Settings.opt("barHeight", 32)
				options: [{ label: "26", value: 26 }, { label: "30", value: 30 }, { label: "32", value: 32 },
					{ label: "36", value: 36 }, { label: "40", value: 40 }]
				onPicked: v => root.writeOpt("barHeight", v)
			}

			LabelRow { width: body.width; label: "Font size"; value: Settings.opt("fontSize", 12) + " px" }
			Choice {
				width: body.width
				current: Settings.opt("fontSize", 12)
				options: [{ label: "11", value: 11 }, { label: "12", value: 12 }, { label: "13", value: 13 }, { label: "14", value: 14 }]
				onPicked: v => root.writeOpt("fontSize", v)
			}

			LabelRow {
				visible: !root.monoTheme
				width: body.width
				label: "Colour intensity"
				value: chromaSlider.shown.toFixed(2)
			}
			OptSlider {
				id: chromaSlider
				visible: !root.monoTheme
				width: body.width
				from: 0; to: 1.5; stepSize: 0.05
				current: Settings.opt("chroma", 1)
				onCommit: v => root.writeOpt("chroma", Math.round(v * 100) / 100)
			}

			LabelRow { width: body.width; label: "Animation speed"; value: Settings.opt("animSpeed", 1) >= 100 ? "off" : Settings.opt("animSpeed", 1) + "x" }
			Choice {
				width: body.width
				current: Settings.opt("animSpeed", 1)
				options: [{ label: "Slow", value: 0.6 }, { label: "Normal", value: 1 }, { label: "Fast", value: 1.6 }, { label: "Off", value: 100 }]
				onPicked: v => root.writeOpt("animSpeed", v)
			}

			Item {
				width: body.width
				height: 20
				Txt { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Light mode"; dim: true }
				Toggle {
					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					checked: Settings.opt("mode", "dark") === "light"
					onToggled: v => root.writeOpt("mode", v ? "light" : "dark")
				}
			}

			Btn {
				visible: !root.scopeAll && Object.keys(root.themeOptions).length > 0
				width: body.width
				flat: true
				text: "Reset this theme's overrides"
				onClicked: Object.keys(root.themeOptions).forEach(k => Settings.setThemeOption(k, null))
			}

			// ---- footer ----
			Sep { width: body.width }
			Item {
				width: body.width
				height: Theme.rowHeight
				Txt {
					anchors.left: parent.left
					anchors.right: editBtn.left
					anchors.rightMargin: Theme.spacing
					anchors.verticalCenter: parent.verticalCenter
					text: Settings.settingsPath.replace(Settings.home, "~")
					mono: true
					muted: true
					size: Theme.fontSmall
					elide: Text.ElideMiddle
				}
				Btn {
					id: editBtn
					anchors.right: parent.right
					flat: true
					text: "Edit settings file"
					onClicked: {
						Quickshell.execDetached([Settings.opt("terminal", "alacritty"), "-e", "nvim", Settings.settingsPath]);
						Ui.close();
					}
				}
			}
		}
	}

		Rectangle {
			visible: flick.visibleArea.heightRatio < 1
			x: parent.width - width
			y: flick.visibleArea.yPosition * flick.height
			width: 3
			height: flick.visibleArea.heightRatio * flick.height
			color: Theme.outline
		}
	}
}
