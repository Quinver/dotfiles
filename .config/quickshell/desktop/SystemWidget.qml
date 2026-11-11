import QtQuick
import qs.config
import qs.services
import qs.widgets

// Desktop system stats: CPU (with history graph), memory and temperature meters.
Item {
	id: root

	implicitWidth: col.implicitWidth + Theme.pad * 2
	implicitHeight: col.implicitHeight + Theme.pad * 2

	Rectangle {
		anchors.fill: parent
		visible: Settings.opt("desktopBackdrop", true)
		radius: Theme.rounding
		color: Theme.alpha(Theme.bg, 0.55)
	}

	component Stat: Item {
		property string label
		property string valueText
		property real value
		width: Theme.fontSize * 16
		height: Theme.fontSize * 2.4
		Txt { text: parent.label; dim: true }
		Txt { anchors.right: parent.right; text: parent.valueText }
		Meter { anchors.bottom: parent.bottom; width: parent.width; value: parent.value }
	}

	Column {
		id: col
		x: Theme.pad
		y: Theme.pad
		spacing: Theme.pad

		Stat { label: "CPU"; value: SysInfo.cpu; valueText: Math.round(SysInfo.cpu * 100) + "%" }
		Graph { width: Theme.fontSize * 16; height: Theme.fontSize * 3; values: SysInfo.cpuHistory }
		Stat { label: "Memory"; value: SysInfo.mem; valueText: Math.round(SysInfo.mem * 100) + "%" }
		Stat {
			label: "Temperature"
			value: SysInfo.cpuTemp / 100
			valueText: Math.round(SysInfo.cpuTemp) + "°C"
		}
	}
}
