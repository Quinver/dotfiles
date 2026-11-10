import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// The bar: one per monitor. Which modules appear, and in what order, comes
// from the barLeft / barCenter / barRight options in settings.json. Every
// name maps to bar/<Name>Module.qml (or bar/<Name>.qml).
PanelWindow {
	id: bar

	required property var modelData
	screen: modelData

	WlrLayershell.namespace: "qs-bar"
	anchors { top: true; left: true; right: true }
	implicitHeight: Theme.barHeight
	exclusiveZone: Theme.barHeight
	color: "transparent"

	Component.onCompleted: Ui.registerBar(bar)
	Component.onDestruction: Ui.unregisterBar(bar)

	Rectangle {
		anchors.fill: parent
		color: Theme.alpha(Theme.bg, Theme.barOpacity)
	}
	Rectangle {
		anchors.bottom: parent.bottom
		width: parent.width
		height: Theme.border
		color: Theme.outlineDim
	}

	component Slot: Loader {
		required property string modelData
		anchors.verticalCenter: parent ? parent.verticalCenter : undefined
		Component.onCompleted: setSource(Qt.resolvedUrl(modelData + "Module.qml"), { screen: bar.screen })
		onStatusChanged: if (status === Loader.Error) console.warn("bar: module failed to load:", modelData)
	}

	Row {
		anchors.left: parent.left
		anchors.verticalCenter: parent.verticalCenter
		height: parent.height
		Repeater { model: Settings.opt("barLeft", []); Slot {} }
	}

	Row {
		anchors.horizontalCenter: parent.horizontalCenter
		anchors.verticalCenter: parent.verticalCenter
		height: parent.height
		Repeater { model: Settings.opt("barCenter", []); Slot {} }
	}

	Row {
		anchors.right: parent.right
		anchors.verticalCenter: parent.verticalCenter
		height: parent.height
		Repeater { model: Settings.opt("barRight", []); Slot {} }
	}
}
