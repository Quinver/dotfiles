import QtQuick
import qs.config
import qs.services
import qs.widgets

// Canvas LMS: book glyph + number of unsubmitted deadlines due soon. Hidden without a token.
BarButton {
	property var screen
	readonly property bool urgent: CanvasLms.dueToday || CanvasLms.newAnnouncements > 0

	visible: CanvasLms.available
	width: visible ? implicitWidth : 0
	icon: Icons.graduation
	popout: "canvas"
	color: urgent ? Theme.primary : Theme.fgDim
	text: CanvasLms.dueSoonCount > 0 ? String(CanvasLms.dueSoonCount) : ""
}
