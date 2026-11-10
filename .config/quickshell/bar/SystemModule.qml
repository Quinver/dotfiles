import QtQuick
import qs.config
import qs.services
import qs.widgets

// CPU usage and temperature; opens the system panel.
BarButton {
	property var screen
	readonly property bool hot: SysInfo.cpuTemp >= 85 || SysInfo.cpu >= 0.9
	readonly property bool warm: SysInfo.cpuTemp >= 75 || SysInfo.cpu >= 0.75
	popout: "system"
	icon: Icons.chip
	color: hot ? Theme.error : warm ? Theme.warn : Theme.fg
	text: Math.round(SysInfo.cpu * 100) + "% " + Math.round(SysInfo.cpuTemp) + "°"
}
