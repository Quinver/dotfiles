import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.widgets

// Hosts whichever popout is open on this monitor (see services/Ui.qml).
// A popout named "audio" is loaded from popouts/AudioPanel.qml.
PanelWindow {
	id: win

	required property var modelData
	screen: modelData

	readonly property bool shown: Ui.popout !== "" && Ui.screen === modelData
	readonly property int maxContentHeight: (screen ? screen.height : 1080) - Theme.barHeight - Theme.gap * 2 - Theme.pad * 2

	function file(name) { return name.charAt(0).toUpperCase() + name.substring(1) + "Panel.qml"; }

	visible: shown
	WlrLayershell.layer: WlrLayer.Top
	WlrLayershell.namespace: "qs-popout"
	WlrLayershell.keyboardFocus: Ui.testMode ? WlrKeyboardFocus.None : WlrKeyboardFocus.OnDemand
	anchors { top: true; left: true; right: true }
	// Reserve no space (popouts float over windows); the top margin keeps
	// them below the bar.
	exclusionMode: ExclusionMode.Ignore
	margins.top: Theme.barHeight
	implicitHeight: frame.height + Theme.gap * 2
	color: "transparent"
	mask: Region { item: frame }

	HyprlandFocusGrab {
		windows: [win].concat(Ui.bars)
		active: win.shown && !Ui.testMode
		onCleared: if (win.shown) Ui.close()
	}

	Box {
		id: frame
		level: 1
		color: Theme.alpha(Theme.surface, Theme.panelOpacity)
		border.color: Theme.outline
		y: win.shown ? Theme.gap : 0
		opacity: win.shown ? 1 : 0
		width: (loader.item ? loader.item.implicitWidth : Theme.popoutWidth) + Theme.pad * 2
		height: Math.min(win.maxContentHeight, loader.item ? loader.item.implicitHeight : 60) + Theme.pad * 2
		x: {
			var want = Ui.anchorX < 0 ? win.width - width - Theme.gap : Ui.anchorX - width / 2;
			return Math.round(Math.max(Theme.gap, Math.min(win.width - width - Theme.gap, want)));
		}
		Behavior on y { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
		Behavior on opacity { NumberAnimation { duration: Theme.anim } }

		// Swallow clicks on the frame so they never fall through.
		MouseArea { anchors.fill: parent }

		Loader {
			id: loader
			anchors.fill: parent
			anchors.margins: Theme.pad
			active: win.shown
			focus: true
			source: win.shown ? Qt.resolvedUrl(win.file(Ui.popout)) : ""
			onStatusChanged: if (status === Loader.Error) console.warn("popout failed to load:", Ui.popout)
		}

		Keys.onEscapePressed: Ui.close()
	}
}
