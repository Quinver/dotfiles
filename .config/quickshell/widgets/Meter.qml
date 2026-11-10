import QtQuick
import qs.config

// Thin progress bar, value 0..1. Colour turns warn/error past the thresholds.
Item {
	id: root

	property real value: 0
	property real warnAt: 0.75
	property real critAt: 0.9
	property color fill: value >= critAt ? Theme.error : value >= warnAt ? Theme.warn : Theme.primary

	implicitWidth: 120
	implicitHeight: 6

	Rectangle {
		anchors.fill: parent
		radius: Math.min(3, Theme.roundingSmall)
		color: Theme.surfaceTop
		Rectangle {
			width: parent.width * Math.max(0, Math.min(1, root.value))
			height: parent.height
			radius: parent.radius
			color: root.fill
			Behavior on width { NumberAnimation { duration: Theme.anim } }
		}
	}
}
