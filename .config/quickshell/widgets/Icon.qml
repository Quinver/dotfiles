import QtQuick
import qs.config

// A Nerd Font glyph: Icon { glyph: Icons.bell }
Text {
	property string glyph: ""
	property int size: Theme.iconSize

	text: glyph
	color: Theme.fg
	font.family: Theme.iconFont
	font.pixelSize: size
	horizontalAlignment: Text.AlignHCenter
	verticalAlignment: Text.AlignVCenter
	width: Math.max(implicitWidth, size + 2)
}
