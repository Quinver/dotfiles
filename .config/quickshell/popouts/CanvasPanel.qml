import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Canvas: upcoming deadlines and recent announcements. Click a row to open it in the browser.
Column {
	id: root
	width: 400
	spacing: Theme.spacing

	SystemClock { id: clock; precision: SystemClock.Minutes }

	function two(n) { return n < 10 ? "0" + n : String(n); }
	function hhmm(d) { return two(d.getHours()) + ":" + two(d.getMinutes()); }
	function dayStart(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime(); }

	// relative due label, local time
	function dueText(iso) {
		const d = new Date(iso), n = clock.date;
		const diff = d.getTime() - n.getTime();
		const hrs = Math.abs(diff) / 3600000;
		if (diff < 0) return hrs < 1 ? "overdue" : hrs < 24 ? "overdue " + Math.floor(hrs) + "h" : "overdue " + Math.floor(hrs / 24) + "d";
		if (hrs < 1) return "in " + Math.max(1, Math.round(diff / 60000)) + "m";
		if (hrs < 6) return "in " + Math.floor(hrs) + "h";
		const days = Math.round((dayStart(d) - dayStart(n)) / 86400000);
		if (days === 0) return "today " + hhmm(d);
		if (days === 1) return "tomorrow " + hhmm(d);
		if (days < 7) return Qt.formatDateTime(d, "ddd") + " " + hhmm(d);
		return Qt.formatDateTime(d, "d MMM") + " " + hhmm(d);
	}

	function dueColor(d) {
		if (d.submitted) return Theme.fgMuted;
		const diff = new Date(d.due).getTime() - clock.date.getTime();
		return diff < 0 ? Theme.error : diff < 86400000 ? Theme.warn : Theme.fgDim;
	}

	function age(iso) {
		const s = (clock.date.getTime() - new Date(iso).getTime()) / 1000;
		if (s < 3600) return Math.max(1, Math.floor(s / 60)) + "m ago";
		if (s < 86400) return Math.floor(s / 3600) + "h ago";
		return Math.floor(s / 86400) + "d ago";
	}

	function updated() {
		if (!CanvasLms.fetched) return "";
		const m = Math.floor((clock.date.getTime() - new Date(CanvasLms.fetched).getTime()) / 60000);
		return m < 1 ? "updated just now" : m < 60 ? "updated " + m + "m ago" : "updated " + Math.floor(m / 60) + "h ago";
	}

	function open(url) {
		if (url) Qt.openUrlExternally(url);
		Ui.close();
	}

	Header {
		width: parent.width
		title: "Canvas"
		Txt { text: (clock.date, root.updated()); size: Theme.fontSmall; muted: true; anchors.verticalCenter: parent.verticalCenter }
		Btn {
			id: refreshBtn
			width: 24
			height: 24
			flat: true
			icon: Icons.refresh
			iconSize: Theme.fontSmall
			opacity: CanvasLms.loading ? 0.5 : 1
			Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
			onClicked: CanvasLms.refresh()
			RotationAnimation on rotation {
				running: CanvasLms.loading
				from: 0; to: 360; duration: 900; loops: Animation.Infinite
				onRunningChanged: if (!running) refreshBtn.rotation = 0
			}
		}
	}

	Txt {
		width: parent.width
		visible: CanvasLms.error !== ""
		text: "Couldn't reach Canvas — " + CanvasLms.error
		color: Theme.error
		size: Theme.fontSmall
	}

	Sep { width: parent.width }

	Header { width: parent.width; title: "Due" }

	Txt {
		width: parent.width
		height: Theme.rowHeight
		visible: CanvasLms.deadlines.length === 0
		text: "Nothing due in the next 3 weeks"
		muted: true
		horizontalAlignment: Text.AlignHCenter
	}

	ListView {
		width: parent.width
		height: Math.min(contentHeight, 220)
		visible: CanvasLms.deadlines.length > 0
		clip: true
		boundsBehavior: Flickable.StopAtBounds
		model: CanvasLms.deadlines
		delegate: Item {
			id: row
			required property var modelData
			width: ListView.view.width
			height: 40
			Rectangle { anchors.fill: parent; color: Theme.surfaceHi; opacity: rowMouse.containsMouse ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.animFast } } }
			Column {
				anchors.left: parent.left
				anchors.right: due.left
				anchors.leftMargin: Theme.pad
				anchors.rightMargin: Theme.spacing
				anchors.verticalCenter: parent.verticalCenter
				Txt { width: parent.width; text: row.modelData.title; color: row.modelData.submitted ? Theme.fgMuted : Theme.fg }
				Txt { width: parent.width; text: row.modelData.course; size: Theme.fontSmall; muted: true }
			}
			Row {
				id: due
				anchors.right: parent.right
				anchors.rightMargin: Theme.pad
				anchors.verticalCenter: parent.verticalCenter
				spacing: 6
				Icon { visible: row.modelData.submitted; glyph: Icons.check; size: Theme.fontSmall; color: Theme.fgMuted; anchors.verticalCenter: parent.verticalCenter }
				Txt { text: (clock.date, root.dueText(row.modelData.due)); size: Theme.fontSmall; color: root.dueColor(row.modelData); anchors.verticalCenter: parent.verticalCenter }
			}
			MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.open(row.modelData.url) }
		}
	}

	Sep { width: parent.width }

	Header { width: parent.width; title: "Announcements" }

	Txt {
		width: parent.width
		height: Theme.rowHeight
		visible: CanvasLms.announcements.length === 0
		text: "No recent announcements"
		muted: true
		horizontalAlignment: Text.AlignHCenter
	}

	ListView {
		width: parent.width
		height: Math.min(contentHeight, 240)
		visible: CanvasLms.announcements.length > 0
		clip: true
		boundsBehavior: Flickable.StopAtBounds
		model: CanvasLms.announcements
		delegate: Item {
			id: arow
			required property var modelData
			width: ListView.view.width
			height: 56
			Rectangle { anchors.fill: parent; color: Theme.surfaceHi; opacity: aMouse.containsMouse ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.animFast } } }
			Rectangle { visible: !arow.modelData.read; width: 2; height: parent.height; color: Theme.primary }
			Column {
				anchors.left: parent.left
				anchors.right: parent.right
				anchors.leftMargin: Theme.pad
				anchors.rightMargin: Theme.pad
				anchors.verticalCenter: parent.verticalCenter
				Txt { width: parent.width; text: arow.modelData.title; bold: !arow.modelData.read }
				Txt { width: parent.width; text: arow.modelData.course + " · " + (clock.date, root.age(arow.modelData.posted)); size: Theme.fontSmall; muted: true }
				Txt { width: parent.width; text: arow.modelData.preview; size: Theme.fontSmall; color: Theme.fgDim }
			}
			MouseArea { id: aMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.open(arow.modelData.url) }
		}
	}
}
