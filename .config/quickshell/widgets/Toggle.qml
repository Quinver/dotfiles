import QtQuick
import qs.config

// On/off switch. Emits toggled(newValue); bind `checked` to your source of truth.
Item {
	id: root

	property bool checked: false
	signal toggled(bool value)

	implicitWidth: 38
	implicitHeight: 20

	Rectangle {
		anchors.fill: parent
		radius: Math.min(height / 2, Theme.roundingSmall)
		color: root.checked ? Theme.primary : Theme.surfaceTop
		border.width: Theme.border
		border.color: root.checked ? Theme.primary : Theme.outline
		Behavior on color { ColorAnimation { duration: Theme.animFast } }

		Rectangle {
			y: 3
			x: root.checked ? parent.width - width - 3 : 3
			width: 14
			height: parent.height - 6
			radius: Math.min(height / 2, Theme.roundingSmall)
			color: root.checked ? Theme.onPrimary : Theme.fgDim
			Behavior on x { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
		}
	}

	MouseArea {
		anchors.fill: parent
		cursorShape: Qt.PointingHandCursor
		onClicked: root.toggled(!root.checked)
	}
}
