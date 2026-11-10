import QtQuick
import qs.config

// Horizontal slider, value 0..1. Emits moved(value) while dragging / scrolling;
// it never changes `value` itself, so bind value to your source of truth.
Item {
	id: root

	property real value: 0
	property color fill: Theme.primary
	property real step: 0.05
	readonly property bool pressed: mouse.pressed

	signal moved(real value)

	implicitWidth: 160
	implicitHeight: 20

	Rectangle {
		id: track
		anchors.verticalCenter: parent.verticalCenter
		width: parent.width
		height: 6
		radius: Math.min(3, Theme.roundingSmall)
		color: Theme.surfaceTop

		Rectangle {
			width: parent.width * Math.max(0, Math.min(1, root.value))
			height: parent.height
			radius: parent.radius
			color: root.enabled ? root.fill : Theme.fgMuted
		}
	}

	Rectangle {
		x: Math.max(0, Math.min(root.width - width, root.width * Math.max(0, Math.min(1, root.value)) - width / 2))
		anchors.verticalCenter: parent.verticalCenter
		width: 4
		height: 16
		radius: Math.min(2, Theme.roundingSmall)
		color: Theme.fg
		visible: root.enabled
	}

	MouseArea {
		id: mouse
		anchors.fill: parent
		preventStealing: true
		function at(x) { return Math.max(0, Math.min(1, x / root.width)); }
		onPressed: function (m) { root.moved(at(m.x)); }
		onPositionChanged: function (m) { if (pressed) root.moved(at(m.x)); }
		onWheel: function (w) {
			root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? root.step : -root.step))));
		}
	}
}
