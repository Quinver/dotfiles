import QtQuick
import qs.config

// Themed rectangle. level 0 = bg, 1 = surface, 2 = surfaceHi, 3 = surfaceTop.
Rectangle {
	property int level: 1
	property bool outlined: true
	property bool small: false      // use the small rounding (buttons, inputs)

	color: level <= 0 ? Theme.bg : level === 1 ? Theme.surface : level === 2 ? Theme.surfaceHi : Theme.surfaceTop
	radius: small ? Theme.roundingSmall : Theme.rounding
	border.width: outlined ? Theme.border : 0
	border.color: Theme.outlineDim
}
