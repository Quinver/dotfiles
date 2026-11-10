import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// System specs and live resource usage. State lives in SysInfo.
Column {
	id: root
	width: Theme.popoutWidth
	spacing: Theme.spacing

	function pct(v) { return Math.round(v * 100) + "%"; }
	function deg(v) { return v > 0 ? Math.round(v) + "°C" : "–"; }

	component StatRow: Item {
		property string label: ""
		property string value: ""
		width: root.width
		height: 18
		Txt { text: parent.label; dim: true; anchors.verticalCenter: parent.verticalCenter }
		Txt { text: parent.value; mono: true; size: Theme.fontSmall; elide: Text.ElideLeft; width: parent.width - 90; horizontalAlignment: Text.AlignRight; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter }
	}

	component Metric: Column {
		id: metric
		property string title: ""
		property string model: ""
		property string usage: ""
		property string detail: ""
		property real frac: 0
		property var history: []
		property bool showMeter: false
		property real meterValue: 0
		width: root.width
		spacing: 4
		Header {
			width: parent.width
			title: parent.title
			Txt { text: metric.usage; mono: true; bold: true }
			Txt { text: metric.detail; mono: true; dim: true }
		}
		Txt { width: parent.width; text: parent.model; size: Theme.fontSmall; muted: true }
		Meter { width: parent.width; visible: parent.showMeter; value: parent.meterValue }
		Graph { width: parent.width; height: 36; values: parent.history; max: 1; line: parent.frac >= 0.9 ? Theme.error : parent.frac >= 0.75 ? Theme.warn : Theme.primary }
	}

	// ---- header ----
	Row {
		spacing: Theme.pad
		Icon { glyph: Icons.chip; size: Theme.fontHuge; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
		Column {
			anchors.verticalCenter: parent.verticalCenter
			Txt { text: SysInfo.hostname || "–"; size: Theme.fontLarge; bold: true }
			Txt { text: (SysInfo.osName || "–") + "  ·  " + (SysInfo.kernel || "–"); dim: true; size: Theme.fontSmall }
			Txt { text: "up " + (SysInfo.uptime || "–"); muted: true; mono: true; size: Theme.fontSmall }
		}
	}

	Sep { width: parent.width }

	Metric {
		title: "CPU"
		model: SysInfo.cpuModel
		usage: root.pct(SysInfo.cpu)
		detail: root.deg(SysInfo.cpuTemp)
		frac: SysInfo.cpu
		history: SysInfo.cpuHistory
	}

	Metric {
		title: "Memory"
		model: SysInfo.fmtBytes(SysInfo.memUsed) + " / " + SysInfo.fmtBytes(SysInfo.memTotal)
		usage: root.pct(SysInfo.mem)
		frac: SysInfo.mem
		history: SysInfo.memHistory
		showMeter: true
		meterValue: SysInfo.mem
	}

	Metric {
		title: "GPU"
		model: SysInfo.gpuModel || "No GPU detected"
		usage: root.pct(SysInfo.gpu)
		detail: root.deg(SysInfo.gpuTemp)
		frac: SysInfo.gpu
		history: SysInfo.gpuHistory
	}

	Row {
		visible: SysInfo.vramTotal > 0
		width: parent.width
		spacing: Theme.spacing
		Txt { id: vramLabel; text: "VRAM"; dim: true; anchors.verticalCenter: parent.verticalCenter }
		Meter { width: parent.width - vramLabel.width - vramText.width - Theme.spacing * 2; value: SysInfo.vramTotal > 0 ? SysInfo.vramUsed / SysInfo.vramTotal : 0; anchors.verticalCenter: parent.verticalCenter }
		Txt { id: vramText; text: SysInfo.fmtBytes(SysInfo.vramUsed) + " / " + SysInfo.fmtBytes(SysInfo.vramTotal); mono: true; size: Theme.fontSmall; anchors.verticalCenter: parent.verticalCenter }
	}

	Sep { width: parent.width }
	Header { width: parent.width; title: "Storage" }

	Txt { visible: SysInfo.disks.length === 0; text: "No disks found"; muted: true }
	Repeater {
		model: SysInfo.disks
		Column {
			required property var modelData
			width: root.width
			spacing: 3
			Item {
				width: parent.width
				height: 16
				Txt { text: modelData.mount; mono: true; size: Theme.fontSmall; width: parent.width * 0.5; anchors.verticalCenter: parent.verticalCenter }
				Txt { text: SysInfo.fmtBytes(modelData.used) + " / " + SysInfo.fmtBytes(modelData.total); mono: true; size: Theme.fontSmall; dim: true; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter }
			}
			Meter { width: parent.width; value: modelData.frac; warnAt: 0.85; critAt: 0.95 }
		}
	}

	Sep { width: parent.width }
	Header { width: parent.width; title: "Hardware" }

	StatRow { label: "CPU"; value: SysInfo.cpuModel + (SysInfo.cpuCores > 0 ? "  " + SysInfo.cpuCores + "C/" + SysInfo.cpuThreads + "T" : "") }
	StatRow { label: "GPU"; value: SysInfo.gpuModel }
	StatRow { label: "RAM"; value: SysInfo.fmtBytes(SysInfo.ramTotal) }
	StatRow { label: "Board"; value: SysInfo.motherboard }
	StatRow { label: "Hyprland"; value: SysInfo.hyprlandVersion }

	Sep { width: parent.width }

	Btn {
		icon: Icons.cpu
		text: "Open btop"
		onClicked: {
			Quickshell.execDetached([Settings.opt("terminal", "alacritty"), "-e", "btop"]);
			Ui.close();
		}
	}
}
