import QtQuick
import qs.config

// Section header for popouts: small caps title on the left, anything you add
// as children is laid out on the right.
Item {
	id: root

	property string title: ""
	default property alias trailing: right.data

	implicitWidth: 200
	implicitHeight: Math.max(22, right.implicitHeight)

	Txt {
		anchors.left: parent.left
		anchors.verticalCenter: parent.verticalCenter
		text: root.title.toUpperCase()
		size: Theme.fontSmall
		bold: true
		muted: true
		font.letterSpacing: 1.2
	}

	Row {
		id: right
		anchors.right: parent.right
		anchors.verticalCenter: parent.verticalCenter
		spacing: Theme.spacing
	}
}
