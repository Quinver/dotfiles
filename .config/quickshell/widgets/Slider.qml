import QtQuick
import qs.config

// Horizontal slider, value 0..max (max defaults to 1; above 1 = boost, drawn in warn with a 100% tick). Emits moved(value) while dragging / scrolling;
// it never changes `value` itself, so bind value to your source of truth.
Item {
	id: root

	property real value: 0
	property color fill: Theme.primary
	property real step: 0.05
	property real max: 1
	readonly property real frac: Math.max(0, Math.min(1, value / max))
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
			width: parent.width * root.frac
			height: parent.height
			radius: parent.radius
			color: !root.enabled ? Theme.fgMuted : (root.value > 1.001 ? Theme.warn : root.fill)
			Behavior on color { ColorAnimation { duration: Theme.animFast } }
		}

		// 100% marker, only when the range goes past 1
		Rectangle {
			visible: root.max > 1
			x: parent.width / root.max - width / 2
			anchors.verticalCenter: parent.verticalCenter
			width: 2
			height: 10
			color: Theme.fgMuted
		}
	}

	Rectangle {
		x: Math.max(0, Math.min(root.width - width, root.width * root.frac - width / 2))
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
		function at(x) { return Math.max(0, Math.min(1, x / root.width)) * root.max; }
		onPressed: function (m) { root.moved(at(m.x)); }
		onPositionChanged: function (m) { if (pressed) root.moved(at(m.x)); }
		onWheel: function (w) {
			root.moved(Math.max(0, Math.min(root.max, root.value + (w.angleDelta.y > 0 ? root.step : -root.step))));
		}
	}
}
