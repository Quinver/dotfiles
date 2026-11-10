import QtQuick
import qs.config
import qs.services

// The standard bar item: optional icon + optional label, hover + active state.
// Set `popout` to make a click toggle that popout under this button.
// Extra children are appended to the row after the label.
Item {
	id: root

	property string icon: ""
	property string text: ""
	property color color: Theme.fg
	property color iconColor: color
	property string popout: ""
	property bool active: popout !== "" && Ui.popout === popout && Ui.screen === Ui.screenOf(root)
	property bool hoverable: true
	property int hpad: Math.round(Theme.pad * 0.8)
	readonly property bool hovered: mouse.containsMouse
	default property alias extra: row.data

	Component.onCompleted: if (popout !== "") Ui.registerButton(root)
	Component.onDestruction: Ui.unregisterButton(root)

	signal clicked()
	signal rightClicked()
	signal middleClicked()
	signal scrolled(int delta)

	implicitWidth: row.implicitWidth + hpad * 2
	implicitHeight: Theme.barHeight
	height: Theme.barHeight

	Rectangle {
		anchors.fill: parent
		color: root.active ? Theme.surfaceTop : Theme.surfaceHi
		opacity: root.active ? 1 : (root.hovered && root.hoverable ? 1 : 0)
		Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
	}

	Rectangle {
		anchors.bottom: parent.bottom
		anchors.left: parent.left
		anchors.right: parent.right
		height: 2
		color: Theme.primary
		visible: root.active
	}

	Row {
		id: row
		anchors.centerIn: parent
		spacing: 6

		Icon {
			visible: root.icon !== ""
			glyph: root.icon
			color: root.iconColor
			anchors.verticalCenter: parent.verticalCenter
		}
		Txt {
			visible: root.text !== ""
			text: root.text
			color: root.color
			anchors.verticalCenter: parent.verticalCenter
		}
	}

	MouseArea {
		id: mouse
		anchors.fill: parent
		hoverEnabled: true
		acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
		onClicked: function (m) {
			if (m.button === Qt.RightButton) root.rightClicked();
			else if (m.button === Qt.MiddleButton) root.middleClicked();
			else {
				if (root.popout !== "") Ui.toggle(root.popout, root);
				root.clicked();
			}
		}
		onWheel: function (w) { if (w.angleDelta.y !== 0) root.scrolled(w.angleDelta.y); }
	}
}
