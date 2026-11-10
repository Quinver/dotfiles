import QtQuick
import qs.config

// Single-line text input. Read `text`, react to accepted() (Enter) and
// edited(text). Set `password: true` to hide the characters.
Box {
	id: root

	property alias text: input.text
	property string placeholder: ""
	property string icon: ""
	property bool password: false
	readonly property alias input: input

	signal accepted()
	signal edited(string text)

	function focusInput() { input.forceActiveFocus(); }

	level: 2
	small: true
	border.color: input.activeFocus ? Theme.primary : Theme.outlineDim
	implicitWidth: 200
	implicitHeight: Theme.rowHeight

	Icon {
		id: ic
		visible: root.icon !== ""
		glyph: root.icon
		color: Theme.fgMuted
		anchors.left: parent.left
		anchors.leftMargin: Theme.pad
		anchors.verticalCenter: parent.verticalCenter
	}

	TextInput {
		id: input
		anchors.left: ic.visible ? ic.right : parent.left
		anchors.leftMargin: ic.visible ? 8 : Theme.pad
		anchors.right: parent.right
		anchors.rightMargin: Theme.pad
		anchors.verticalCenter: parent.verticalCenter
		color: Theme.fg
		selectionColor: Theme.primaryDim
		selectedTextColor: Theme.fg
		font.family: Theme.font
		font.pixelSize: Theme.fontSize
		clip: true
		echoMode: root.password ? TextInput.Password : TextInput.Normal
		onAccepted: root.accepted()
		onTextEdited: root.edited(text)

		Txt {
			anchors.fill: parent
			visible: input.text === ""
			text: root.placeholder
			muted: true
		}
	}
}
