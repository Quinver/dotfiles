import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// One wallpaper surface per connected monitor, cross-fading between images.
// Two image layers take turns: the incoming one loads hidden, fades in once
// ready, and the outgoing one is unloaded after the fade to free its memory.
PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	WlrLayershell.layer: WlrLayer.Background
	WlrLayershell.namespace: "qs-wallpaper"
	exclusionMode: ExclusionMode.Ignore
	anchors { top: true; bottom: true; left: true; right: true }
	color: Theme.bg

	property string shown: ""     // path currently requested
	property Image front: null    // layer that is (becoming) visible
	readonly property int fadeMs: Theme.animSlow * 2

	function show(path) {
		if (path === "" || path === shown) return;
		shown = path;
		var incoming = front === a ? b : a;
		incoming.source = "";                 // force a fresh load, even of a path used before
		incoming.source = Wallpapers.url(path);
	}

	function ready(layer) {
		if (layer.source.toString() !== Wallpapers.url(shown)) return;   // a newer request superseded it
		var outgoing = layer === a ? b : a;
		front = layer;
		layer.opacity = 1;
		outgoing.opacity = 0;
		unload.restart();
	}

	Timer {
		id: unload
		interval: root.fadeMs + 200
		onTriggered: {
			var back = root.front === a ? b : a;
			if (back.opacity === 0) back.source = "";
		}
	}

	// If an image fails to load, do not stay blank: try the next request again later.
	Timer {
		id: retry
		interval: 3000
		onTriggered: { var p = root.shown; root.shown = ""; root.show(p); }
	}

	Connections {
		target: Wallpapers
		function onCurrentChanged() { root.show(Wallpapers.current); }
	}
	Component.onCompleted: show(Wallpapers.current)

	component Layer: Image {
		anchors.fill: parent
		fillMode: Image.PreserveAspectCrop
		asynchronous: true
		cache: false
		smooth: true
		sourceSize.width: root.screen ? root.screen.width : 1920
		sourceSize.height: root.screen ? root.screen.height : 1080
		opacity: 0
		Behavior on opacity { NumberAnimation { duration: root.fadeMs; easing.type: Easing.InOutQuad } }
		onStatusChanged: {
			if (status === Image.Ready) root.ready(this);
			else if (status === Image.Error) retry.restart();
		}
	}

	Layer { id: a }
	Layer { id: b }
}
