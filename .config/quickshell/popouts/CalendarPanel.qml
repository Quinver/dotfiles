import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Big clock, full date and a Monday-first month grid with ISO week numbers.
Column {
	id: root
	width: Theme.popoutWidth
	spacing: Theme.spacing

	property int viewYear: Clock.date.getFullYear()
	property int viewMonth: Clock.date.getMonth()
	readonly property var weeks: monthGrid(viewYear, viewMonth)
	readonly property real cellW: (width - weekCol) / 7
	readonly property int weekCol: 28

	// 6 rows of { week, days: [{ d, m, y, inMonth }] }, Monday first.
	function monthGrid(year, month) {
		var first = new Date(year, month, 1);
		var lead = (first.getDay() + 6) % 7;
		var out = [];
		for (var r = 0; r < 6; r++) {
			var days = [];
			for (var c = 0; c < 7; c++) {
				var dt = new Date(year, month, 1 - lead + r * 7 + c);
				days.push({ d: dt.getDate(), m: dt.getMonth(), y: dt.getFullYear(), inMonth: dt.getMonth() === month });
			}
			var mid = days[3];
			out.push({ week: isoWeek(mid.y, mid.m, mid.d), days: days });
		}
		return out;
	}

	function isoWeek(y, m, d) {
		var dt = new Date(Date.UTC(y, m, d));
		var dow = (dt.getUTCDay() + 6) % 7;
		dt.setUTCDate(dt.getUTCDate() - dow + 3);
		var jan4 = new Date(Date.UTC(dt.getUTCFullYear(), 0, 4));
		return 1 + Math.round(((dt - jan4) / 86400000 - 3 + ((jan4.getUTCDay() + 6) % 7)) / 7);
	}

	function shift(delta) {
		var d = new Date(viewYear, viewMonth + delta, 1);
		viewYear = d.getFullYear();
		viewMonth = d.getMonth();
	}

	function today() {
		viewYear = Clock.date.getFullYear();
		viewMonth = Clock.date.getMonth();
	}

	SystemClock { id: secs; precision: SystemClock.Seconds }

	Txt {
		width: parent.width
		horizontalAlignment: Text.AlignHCenter
		text: Qt.formatTime(secs.date, "HH:mm:ss")
		size: Theme.fontHuge
		mono: true
	}
	Txt {
		width: parent.width
		horizontalAlignment: Text.AlignHCenter
		text: Qt.formatDate(secs.date, "dddd d MMMM yyyy")
		dim: true
	}

	Sep { width: parent.width }

	Header {
		width: parent.width
		implicitHeight: Theme.rowHeight
		title: Qt.locale().monthName(root.viewMonth) + " " + root.viewYear
		Btn { flat: true; icon: Icons.chevronLeft; onClicked: root.shift(-1) }
		Btn { flat: true; text: "Today"; onClicked: root.today() }
		Btn { flat: true; icon: Icons.chevronRight; onClicked: root.shift(1) }
	}

	Row {
		Item { width: root.weekCol; height: 22 }
		Repeater {
			model: [1, 2, 3, 4, 5, 6, 0]
			Txt {
				required property int modelData
				width: root.cellW
				height: 22
				horizontalAlignment: Text.AlignHCenter
				text: Qt.locale().dayName(modelData, Locale.ShortFormat)
				size: Theme.fontSmall
				muted: true
			}
		}
	}

	Column {
		id: grid
		Repeater {
			model: root.weeks
			Row {
				id: weekRow
				required property var modelData
				Txt {
					width: root.weekCol
					height: root.cellW * 0.8
					horizontalAlignment: Text.AlignHCenter
					text: weekRow.modelData.week
					size: Theme.fontSmall
					muted: true
				}
				Repeater {
					model: weekRow.modelData.days
					Rectangle {
						id: cell
						required property var modelData
						readonly property bool isToday: modelData.d === Clock.date.getDate() && modelData.m === Clock.date.getMonth() && modelData.y === Clock.date.getFullYear()
						width: root.cellW
						height: root.cellW * 0.8
						radius: Theme.roundingSmall
						color: isToday ? Theme.primary : hover.hovered ? Theme.surfaceHi : "transparent"
						HoverHandler { id: hover }
						Txt {
							anchors.centerIn: parent
							text: cell.modelData.d
							color: cell.isToday ? Theme.onPrimary : cell.modelData.inMonth ? Theme.fg : Theme.fgMuted
							bold: cell.isToday
						}
					}
				}
			}
		}
	}

	WheelHandler {
		target: null
		onWheel: event => root.shift(event.angleDelta.y < 0 ? 1 : -1)
	}
}
