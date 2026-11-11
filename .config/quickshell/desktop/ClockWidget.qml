import QtQuick
import qs.config
import qs.services
import qs.widgets

// Big desktop clock: time, date and a thin accent line, optional soft backdrop.
Item {
	id: root

	readonly property bool backdrop: Settings.opt("desktopBackdrop", true)
	readonly property int inset: backdrop ? Theme.pad * 2 : 0

	implicitWidth: Math.max(time.implicitWidth, date.implicitWidth) + inset * 2
	implicitHeight: content.implicitHeight + inset * 2

	Rectangle {
		anchors.fill: parent
		visible: root.backdrop
		radius: Theme.rounding
		color: Theme.alpha(Theme.bg, 0.55)
	}

	Column {
		id: content
		x: root.inset
		y: root.inset
		spacing: Theme.spacing

		Txt {
			id: time
			size: Theme.fontSize * 4
			bold: true
			text: Qt.formatDateTime(Clock.date, Settings.opt("clockFormat", "HH:mm"))
		}
		Rectangle {
			width: Theme.fontSize * 4
			height: 2
			radius: 1
			color: Theme.primary
		}
		Txt {
			id: date
			size: Theme.fontLarge
			dim: true
			text: Qt.formatDateTime(Clock.date, Settings.opt("dateFormat", "ddd d MMM"))
		}
	}
}
