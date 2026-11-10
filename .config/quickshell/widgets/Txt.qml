import QtQuick
import qs.config

// Themed text. `dim` / `muted` pick the secondary colours, `mono` the monospace font.
Text {
	property bool dim: false
	property bool muted: false
	property bool mono: false
	property bool bold: false
	property int size: Theme.fontSize

	color: muted ? Theme.fgMuted : dim ? Theme.fgDim : Theme.fg
	font.family: mono ? Theme.monoFont : Theme.font
	font.pixelSize: size
	font.weight: bold ? Font.DemiBold : Font.Normal
	elide: Text.ElideRight
	textFormat: Text.PlainText
	verticalAlignment: Text.AlignVCenter
}
