import QtQuick
import qs.config
import qs.services
import qs.widgets

// Burger menu: opens the control centre. Middle click toggles safe mode,
// right click opens the power menu. A small eye-slash hint shows while the
// safe theme is active.
BarButton {
	property var screen

	icon: Icons.menu
	iconColor: Theme.primary
	popout: "control"
	onMiddleClicked: Settings.toggleSafe()
	onRightClicked: Ui.toggleOverlay("power")

	Icon {
		visible: Settings.safeActive
		glyph: Icons.eyeSlash
		size: Theme.fontSmall
		color: Theme.fgDim
		anchors.verticalCenter: parent.verticalCenter
	}
}
