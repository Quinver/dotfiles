import QtQuick
import Quickshell
import Quickshell.Widgets
import QtQuick.Effects
import qs.config

// Application icon from a window class / app id / desktop entry id / icon name.
//   AppIcon { app: "firefox"; size: 18 }
// With the iconStyle option set to "tinted" (default) the icon is drawn in
// shades of the theme colour instead of its own colours; "color" shows it as is.
// Falls back to a neutral glyph when the icon theme has nothing for it.
Item {
	id: root

	property string app: ""
	property int size: 18
	readonly property var entry: app !== "" ? DesktopEntries.heuristicLookup(app) : null
	readonly property string iconName: entry && entry.icon ? entry.icon : app.toLowerCase()
	readonly property string path: iconName === "" ? ""
		: iconName.charAt(0) === "/" ? "file://" + iconName
		: iconName.indexOf("://") !== -1 ? iconName
		: Quickshell.iconPath(iconName, true)
	readonly property string shown: source !== "" ? source : path

	readonly property bool tinted: Settings.opt("iconStyle", "tinted") === "tinted"
	// Any image URL may be given directly instead of an app name (tray icons).
	property string source: ""

	implicitWidth: size
	implicitHeight: size
	width: size
	height: size

	IconImage {
		id: img
		anchors.fill: parent
		visible: root.shown !== "" && !root.tinted
		implicitSize: root.size
		asynchronous: true
		source: root.shown
	}

	MultiEffect {
		anchors.fill: parent
		visible: root.shown !== "" && root.tinted
		source: img
		colorization: 1
		colorizationColor: Theme.primary
		brightness: 0.15
		contrast: 0.2
	}

	Icon {
		anchors.centerIn: parent
		visible: root.shown === ""
		glyph: Icons.cube
		size: Math.round(root.size * 0.8)
		color: Theme.fgDim
	}
}
