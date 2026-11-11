import QtQuick
import qs.config
import qs.services
import qs.widgets

// Desktop now-playing card: art, title/artist, progress, transport. Hidden without a player.
Item {
	id: root

	readonly property bool active: Media.player !== null && Media.title !== ""
	readonly property int art: Theme.rowHeight * 3

	implicitWidth: row.implicitWidth + Theme.pad * 2
	implicitHeight: row.implicitHeight + Theme.pad * 2

	// Progress needs the 1 s position tick only while visible.
	onVisibleChanged: { if (visible) Media.watchers++; else Media.watchers--; }
	Component.onCompleted: if (visible) Media.watchers++
	Component.onDestruction: if (visible) Media.watchers--

	Rectangle {
		anchors.fill: parent
		visible: Settings.opt("desktopBackdrop", true)
		radius: Theme.rounding
		color: Theme.alpha(Theme.bg, 0.55)
	}

	Row {
		id: row
		x: Theme.pad
		y: Theme.pad
		spacing: Theme.pad

		Rectangle {
			width: root.art
			height: root.art
			radius: Theme.rounding
			color: Theme.surfaceHi
			clip: true
			Image {
				anchors.fill: parent
				source: Media.artUrl
				fillMode: Image.PreserveAspectCrop
				asynchronous: true
			}
		}

		Column {
			width: Theme.fontSize * 16
			spacing: Theme.spacing
			anchors.verticalCenter: parent.verticalCenter

			Txt { width: parent.width; text: Media.title; bold: true; size: Theme.fontLarge }
			Txt { width: parent.width; text: Media.artist; dim: true }
			Meter {
				width: parent.width
				value: Media.length > 0 ? Media.position / Media.length : 0
				warnAt: 2
				critAt: 2
			}
			Row {
				spacing: Theme.spacing
				Btn { flat: true; icon: Icons.previous; onClicked: Media.previous() }
				Btn { accent: true; icon: Media.playing ? Icons.pause : Icons.play; onClicked: Media.toggle() }
				Btn { flat: true; icon: Icons.next; onClicked: Media.next() }
			}
		}
	}
}
