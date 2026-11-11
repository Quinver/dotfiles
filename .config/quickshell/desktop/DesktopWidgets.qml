import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Desktop widgets (clock, now playing, system stats): one small window per
// monitor on the Bottom layer, anchored to a corner and sized to its content,
// so clicks anywhere else on the desktop still reach the compositor.
PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	readonly property string position: Settings.opt("desktopPosition", "bottom-left")
	readonly property string onlyScreen: Settings.opt("desktopScreen", "")
	readonly property bool wantClock: Settings.opt("desktopClock", true)
	readonly property bool wantMedia: Settings.opt("desktopMedia", true)
	readonly property bool wantSystem: Settings.opt("desktopSystem", false)
	readonly property bool top: position.indexOf("top") === 0
	readonly property bool center: position.indexOf("center") === 0
	readonly property bool right: position.indexOf("right") >= 0
	readonly property int edge: Theme.gap * 8

	visible: (wantClock || wantMedia || wantSystem) && (onlyScreen === "" || (screen && screen.name === onlyScreen))

	WlrLayershell.layer: WlrLayer.Bottom
	WlrLayershell.namespace: "qs-desktop"
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
	exclusionMode: ExclusionMode.Ignore
	color: "transparent"

	anchors { left: !root.right; right: root.right; top: root.top; bottom: !root.top && !root.center }
	margins {
		left: edge
		right: edge
		top: root.top ? edge + Theme.barHeight : 0
		bottom: root.top || root.center ? 0 : edge
	}

	implicitWidth: col.implicitWidth
	implicitHeight: col.implicitHeight

	Column {
		id: col
		spacing: Theme.gap * 2

		ClockWidget { visible: root.wantClock }
		MediaWidget { visible: root.wantMedia && active }
		SystemWidget { visible: root.wantSystem }
	}
}
