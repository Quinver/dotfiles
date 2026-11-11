import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

// Control centre (the burger menu): identity + quick toggles, theme/settings launchers,
// wallpaper preview and quick controls, settings file shortcut.
// Everything below the top row scrolls.
Column {
	id: root

	property string hostname: ""

	width: 400
	spacing: Theme.spacing

	function baseName(path) { return path ? path.split("/").pop() : ""; }

	FileView {
		path: "/etc/hostname"
		blockLoading: true
		onLoaded: root.hostname = text().trim()
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
			Item {
				width: body.width
				height: Theme.rowHeight
				Txt {
					anchors.left: parent.left
					anchors.right: themeBtns.left
					anchors.rightMargin: Theme.spacing
					anchors.verticalCenter: parent.verticalCenter
					text: Settings.themeLabel(Settings.themeName)
					bold: true
					elide: Text.ElideRight
				}
				Row {
					id: themeBtns
					anchors.right: parent.right
					spacing: Theme.spacing
					Btn { icon: Icons.brush; text: "Browse themes"; onClicked: Ui.toggleOverlay("themes") }
					Btn { icon: Icons.sliders; text: "Settings"; onClicked: Ui.toggleOverlay("settings") }
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
