import QtQuick
import qs.config

// Sparkline. `values` is an array of numbers in 0..max (newest last).
Canvas {
	id: root

	property var values: []
	property real max: 1
	property color line: Theme.primary
	property bool filled: true

	implicitWidth: 160
	implicitHeight: 40

	onValuesChanged: requestPaint()
	onLineChanged: requestPaint()
	onWidthChanged: requestPaint()
	onHeightChanged: requestPaint()

	onPaint: {
		var ctx = getContext("2d");
		ctx.reset();
		var v = root.values || [];
		if (v.length < 2) return;
		var w = width, h = height, m = Math.max(0.0001, root.max);
		var step = w / (v.length - 1);
		ctx.beginPath();
		for (var i = 0; i < v.length; i++) {
			var y = h - 1 - Math.max(0, Math.min(1, v[i] / m)) * (h - 2);
			if (i === 0) ctx.moveTo(0, y); else ctx.lineTo(i * step, y);
		}
		ctx.strokeStyle = root.line;
		ctx.lineWidth = 1.5;
		ctx.stroke();
		if (root.filled) {
			ctx.lineTo(w, h);
			ctx.lineTo(0, h);
			ctx.closePath();
			ctx.fillStyle = Qt.rgba(root.line.r, root.line.g, root.line.b, 0.15);
			ctx.fill();
		}
	}
}
