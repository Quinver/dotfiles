import QtQuick
import qs.config

// Button for popouts / overlays. Optional icon and/or text.
//   accent: true  -> filled with the accent colour
//   flat: true    -> no background until hovered
//   checked: true -> selected look (for toggles / tabs)
Item {
	id: root

	property string icon: ""
	property string text: ""
	property bool accent: false
	property bool flat: false
	property bool checked: false
	property bool danger: false
	property int iconSize: Theme.iconSize
	readonly property bool hovered: mouse.containsMouse
	readonly property color fgColor: !enabled ? Theme.fgMuted
		: (accent || checked) ? Theme.onPrimary : danger ? Theme.error : Theme.fg

	signal clicked()
	signal rightClicked()

	implicitWidth: Math.max(Theme.rowHeight, row.implicitWidth + Theme.pad * 2)
	implicitHeight: Theme.rowHeight

	Rectangle {
		anchors.fill: parent
		radius: Theme.roundingSmall
		color: (root.accent || root.checked) ? Theme.primary
			: mouse.pressed ? Theme.surfaceTop
			: root.hovered ? Theme.surfaceTop
			: root.flat ? "transparent" : Theme.surfaceHi
		opacity: (root.accent || root.checked) && root.hovered ? 0.85 : 1
		border.width: root.flat || root.accent || root.checked ? 0 : Theme.border
		border.color: Theme.outlineDim
		Behavior on color { ColorAnimation { duration: Theme.animFast } }
	}

	Row {
		id: row
		anchors.centerIn: parent
		spacing: 7
		Icon {
			visible: root.icon !== ""
			glyph: root.icon
			size: root.iconSize
			color: root.fgColor
			anchors.verticalCenter: parent.verticalCenter
		}
		Txt {
			visible: root.text !== ""
			text: root.text
			color: root.fgColor
			anchors.verticalCenter: parent.verticalCenter
		}
	}

	MouseArea {
		id: mouse
		anchors.fill: parent
		hoverEnabled: true
		acceptedButtons: Qt.LeftButton | Qt.RightButton
		cursorShape: Qt.PointingHandCursor
		onClicked: function (m) {
			if (m.button === Qt.RightButton) root.rightClicked();
			else root.clicked();
		}
	}
}
