import QtQuick
import qs.config

// 1px separator. Horizontal by default; set vertical: true inside a Row.
Rectangle {
	property bool vertical: false
	implicitWidth: vertical ? 1 : 10
	implicitHeight: vertical ? 10 : 1
	color: Theme.outlineDim
}
