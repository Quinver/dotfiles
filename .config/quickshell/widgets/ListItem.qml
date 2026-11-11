import QtQuick
import qs.config

// A clickable row: [icon] title / subtitle ............ [trailing children]
// Children you add go to the right-hand side.
Item {
	id: root

	property string icon: ""
	property color iconColor: Theme.fgDim
	property string title: ""
	property string subtitle: ""
	property bool selected: false
	property bool interactive: true
	// Lists whose selection already follows the mouse can turn this off.
	property bool hoverHighlight: true
	readonly property bool hovered: mouse.containsMouse
	default property alias trailing: right.data
	// Put a custom leading item (e.g. an app icon) here instead of a glyph.
	property alias leading: lead.data

	signal clicked()
	signal rightClicked()

	implicitWidth: 200
	implicitHeight: root.subtitle !== "" ? Theme.rowHeight + 10 : Theme.rowHeight

	Rectangle {
		anchors.fill: parent
		radius: Theme.roundingSmall
		color: root.selected ? Theme.surfaceTop : Theme.surfaceHi
		opacity: root.selected || (root.hovered && root.interactive && root.hoverHighlight) ? 1 : 0
	}

	Rectangle {
		visible: root.selected
		width: 2
		height: parent.height
		color: Theme.primary
	}

	MouseArea {
		id: mouse
		anchors.fill: parent
		hoverEnabled: true
		acceptedButtons: Qt.LeftButton | Qt.RightButton
		onClicked: function (m) {
			if (!root.interactive) return;
			if (m.button === Qt.RightButton) root.rightClicked();
			else root.clicked();
		}
	}

	Row {
		id: left
		anchors.left: parent.left
		anchors.leftMargin: Theme.pad
		anchors.right: right.left
		anchors.rightMargin: Theme.spacing
		anchors.verticalCenter: parent.verticalCenter
		spacing: Theme.pad

		Item {
			id: lead
			visible: children.length > 0
			width: childrenRect.width
			height: childrenRect.height
			anchors.verticalCenter: parent.verticalCenter
		}
		Icon {
			visible: root.icon !== ""
			glyph: root.icon
			color: root.iconColor
			anchors.verticalCenter: parent.verticalCenter
		}
		Column {
			anchors.verticalCenter: parent.verticalCenter
			width: parent.width - (lead.visible ? lead.width + parent.spacing : 0) - (root.icon !== "" ? Theme.iconSize + 2 + parent.spacing : 0)
			Txt { width: parent.width; text: root.title }
			Txt { width: parent.width; visible: root.subtitle !== ""; text: root.subtitle; size: Theme.fontSmall; muted: true }
		}
	}

	Row {
		id: right
		anchors.right: parent.right
		anchors.rightMargin: Theme.pad
		anchors.verticalCenter: parent.verticalCenter
		spacing: Theme.spacing
	}
}
