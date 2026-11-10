import QtQuick
import qs.config
import qs.services
import qs.widgets

// Bell with unread count. Click: notification centre. Right: toggle DND. Middle: clear all.
BarButton {
	property var screen
	popout: "notifications"
	icon: Notifs.dnd ? Icons.bellOff : Icons.bell
	iconColor: Notifs.dnd ? Theme.fgMuted : Theme.fg
	text: Notifs.count > 0 ? String(Notifs.count) : ""
	color: Notifs.hasCritical ? Theme.error : Theme.primary
	onRightClicked: Notifs.toggleDnd()
	onMiddleClicked: Notifs.dismissAll()
}
