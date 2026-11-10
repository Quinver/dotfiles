import QtQuick
import qs.config
import qs.services
import qs.widgets

// Bluetooth icon (+ count when several devices are connected). Hidden without an
// adapter. Click opens the panel, middle click toggles power.
BarButton {
	property var screen
	visible: Bt.available
	popout: "bluetooth"
	icon: Icons.bluetooth
	text: Bt.connectedCount > 1 ? String(Bt.connectedCount) : ""
	color: iconColor
	iconColor: Bt.connectedCount > 0 ? Theme.primary : Bt.enabled ? Theme.fg : Theme.fgMuted
	onMiddleClicked: Bt.setEnabled(!Bt.enabled)
}
