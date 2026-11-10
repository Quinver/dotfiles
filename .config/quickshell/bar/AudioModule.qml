import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Speaker icon + volume %. Scroll = volume, middle = mute, right = mixer.
BarButton {
	property var screen

	readonly property bool off: Audio.muted || Audio.volume <= 0
	popout: "audio"
	icon: off ? Icons.volumeOff : Audio.volume < 0.5 ? Icons.volumeLow : Icons.volumeHigh
	text: Math.round(Audio.volume * 100) + "%"
	color: Audio.muted ? Theme.fgMuted : Theme.fg

	onScrolled: delta => Audio.changeVolume(delta > 0 ? 0.05 : -0.05)
	onMiddleClicked: Audio.toggleMute()
	onRightClicked: Quickshell.execDetached(["pwvucontrol"])

	Icon {
		visible: Audio.micMuted
		glyph: Icons.micOff
		size: Theme.fontSize
		color: Theme.warn
		anchors.verticalCenter: parent.verticalCenter
	}
}
