import QtQuick
import qs.config
import qs.services
import qs.widgets

// Network status icon. Click opens the panel, middle click toggles wifi.
BarButton {
	property var screen
	popout: "network"
	icon: Net.kind === "ethernet" ? Icons.ethernet : Net.kind === "none" ? Icons.ban : Icons.wifi
	iconColor: Net.kind === "none" ? Theme.error
		: Net.kind === "off" ? Theme.fgMuted
		: Net.kind === "wifi" ? (Net.strength < 0.3 ? Theme.warn : Net.strength < 0.6 ? Theme.fgDim : Theme.fg)
		: Theme.fg
	onMiddleClicked: Net.setWifiEnabled(!Net.wifiEnabled)
}
