import QtQuick
import qs.config
import qs.services
import qs.widgets

// Date (dim) and time (bold) in the bar; click opens the calendar popout.
BarButton {
	property var screen
	popout: "calendar"

	Txt { dim: true; text: Qt.formatDateTime(Clock.date, Settings.opt("dateFormat", "ddd d MMM")); anchors.verticalCenter: parent.verticalCenter }
	Txt { bold: true; text: Qt.formatDateTime(Clock.date, Settings.opt("clockFormat", "HH:mm")); anchors.verticalCenter: parent.verticalCenter }
}
