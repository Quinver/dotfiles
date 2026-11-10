import QtQuick
import qs.config
import qs.services
import qs.widgets

// Wallpaper picker: thumbnail grid of the active theme's folder, rotation
// controls and a theme switcher. Opened from the control centre's Browse button.
Column {
	id: root

	width: 640
	spacing: Theme.spacing

	function baseName(path) { return path.split("/").pop(); }

	Component.onCompleted: Wallpapers.refresh()

	Item {
		width: root.width
		height: Theme.rowHeight

		Row {
			anchors.left: parent.left
			anchors.verticalCenter: parent.verticalCenter
			spacing: Theme.spacing
			Txt { text: Settings.themeLabel(Settings.themeName); bold: true; size: Theme.fontLarge }
			Txt { text: Wallpapers.files.length + " wallpapers"; dim: true; anchors.verticalCenter: parent.verticalCenter }
		}
		Row {
			anchors.right: parent.right
			spacing: Theme.spacing / 2
			Btn { flat: true; icon: Icons.previous; onClicked: Wallpapers.prev() }
			Btn { flat: true; icon: Icons.next; onClicked: Wallpapers.next() }
			Btn {
				flat: true
				icon: Settings.state.rotatePaused ? Icons.play : Icons.pause
				checked: !!Settings.state.rotatePaused
				onClicked: Wallpapers.togglePause()
			}
		}
	}

	GridView {
		id: grid
		visible: Wallpapers.files.length > 0
		width: root.width
		height: Math.min(contentHeight, 520)
		cellWidth: Math.floor(width / 3)
		cellHeight: Math.round(cellWidth * 9 / 16)
		clip: true
		cacheBuffer: 400
		boundsBehavior: Flickable.StopAtBounds
		model: Wallpapers.files

		delegate: Item {
			id: cell
			required property string modelData
			readonly property bool current: modelData === Wallpapers.current
			width: grid.cellWidth
			height: grid.cellHeight

			Item {
				anchors.fill: parent
				anchors.margins: 3

				Rectangle { anchors.fill: parent; color: Theme.surfaceHi }
				Image {
					anchors.fill: parent
					source: Wallpapers.url(cell.modelData)
					asynchronous: true
					sourceSize.width: 320
					fillMode: Image.PreserveAspectCrop
				}
				Rectangle {
					visible: tileMouse.containsMouse
					anchors.left: parent.left
					anchors.right: parent.right
					anchors.bottom: parent.bottom
					height: 24
					color: Qt.rgba(0, 0, 0, 0.6)
					Txt {
						anchors.fill: parent
						anchors.leftMargin: Theme.spacing
						anchors.rightMargin: Theme.spacing
						text: root.baseName(cell.modelData)
						color: "white"
						size: Theme.fontSmall
					}
				}
				Rectangle {
					anchors.fill: parent
					color: "transparent"
					border.width: cell.current ? 2 : 0
					border.color: Theme.primary
				}
				MouseArea {
					id: tileMouse
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onClicked: Wallpapers.set(cell.modelData)
				}
			}
		}
	}

	Column {
		visible: Wallpapers.files.length === 0
		width: root.width
		spacing: Theme.spacing
		topPadding: Theme.pad
		bottomPadding: Theme.pad

		Txt { width: parent.width; text: "No images in"; horizontalAlignment: Text.AlignHCenter; dim: true }
		Txt { width: parent.width; text: Wallpapers.dir; mono: true; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideMiddle }
		Txt {
			width: parent.width
			text: "Images dropped into that folder appear automatically."
			horizontalAlignment: Text.AlignHCenter
			muted: true
			size: Theme.fontSmall
		}
	}

	Sep { width: root.width }

	Flow {
		width: root.width
		spacing: Theme.spacing
		Repeater {
			model: Settings.themeNames
			Btn {
				required property string modelData
				text: Settings.themeLabel(modelData)
				checked: Settings.themeName === modelData
				onClicked: Settings.setTheme(modelData)
			}
		}
	}
}
