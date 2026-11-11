import QtQuick
import qs.config
import qs.services
import qs.widgets

// fcitx5 state: "あ" (Japanese, primary) or "A" (keyboard). Click toggles, right click opens fcitx5-configtool.
BarButton {
	property var screen

	visible: Ime.available
	width: visible ? implicitWidth : 0
	onClicked: Ime.toggle()
	onRightClicked: Ime.openConfig()

	Txt {
		text: Ime.japanese ? "あ" : "A"
		bold: true
		color: Ime.japanese ? Theme.primary : Theme.fgDim
		font.family: Ime.japanese ? "Noto Sans CJK JP" : Theme.font
		anchors.verticalCenter: parent.verticalCenter
		Behavior on color { ColorAnimation { duration: Theme.animFast } }
	}
}
