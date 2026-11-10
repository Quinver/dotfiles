import QtQuick
import qs.config
import qs.services
import qs.widgets

// Clipboard history (cliphist): search, click or Enter to copy, hover for delete.
// Keys: Up/Down move the selection, Enter copies it, Escape closes.
Column {
	id: root
	width: Theme.popoutWidth
	spacing: Theme.spacing

	property int current: 0
	readonly property var shown: {
		var q = search.text.trim().toLowerCase();
		return q === "" ? Clipboard.entries : Clipboard.entries.filter(e => e.preview.toLowerCase().indexOf(q) >= 0);
	}

	function pick(e) {
		Clipboard.copy(e.line);
		Ui.close();
	}
	function move(d) {
		if (shown.length === 0) return;
		current = Math.max(0, Math.min(shown.length - 1, current + d));
		view.positionViewAtIndex(current, ListView.Contain);
	}
	// "[[ binary data 12 KiB png 800x600 ]]" -> "12 KiB png 800x600"
	function imageInfo(p) { return p.replace(/^\[\[ binary data\s*/, "").replace(/\s*\]\]$/, ""); }

	Component.onCompleted: {
		Clipboard.refresh();
		search.focusInput();
	}

	Header {
		width: parent.width
		title: "Clipboard"
		Btn {
			flat: true
			danger: true
			icon: Icons.trash
			iconSize: Theme.fontSmall
			enabled: Clipboard.entries.length > 0
			height: 24
			onClicked: Clipboard.wipe()
		}
	}

	Field {
		id: search
		width: parent.width
		icon: Icons.search
		placeholder: "Search"
		onEdited: root.current = 0
		onAccepted: if (root.shown.length > 0) root.pick(root.shown[root.current])
		input.Keys.onPressed: function (ev) {
			if (ev.key === Qt.Key_Down) { root.move(1); ev.accepted = true; }
			else if (ev.key === Qt.Key_Up) { root.move(-1); ev.accepted = true; }
			else if (ev.key === Qt.Key_Escape) { Ui.close(); ev.accepted = true; }
		}
	}

	Sep { width: parent.width }

	Item {
		width: parent.width
		height: 80
		visible: root.shown.length === 0
		Txt {
			anchors.centerIn: parent
			text: Clipboard.entries.length === 0 ? "Clipboard is empty" : "No matches"
			muted: true
		}
	}

	ListView {
		id: view
		width: parent.width
		height: Math.min(contentHeight, 420)
		visible: root.shown.length > 0
		clip: true
		boundsBehavior: Flickable.StopAtBounds
		model: root.shown

		delegate: ListItem {
			id: row
			required property var modelData
			required property int index
			width: view.width
			selected: index === root.current
			icon: modelData.isImage ? Icons.image : ""
			title: modelData.isImage ? "Image" : modelData.preview
			subtitle: modelData.isImage ? root.imageInfo(modelData.preview) : ""
			onClicked: root.pick(modelData)

			Btn {
				flat: true
				danger: true
				width: 24
				height: 24
				icon: Icons.close
				iconSize: Theme.fontSmall
				opacity: row.hovered || hovered ? 1 : 0
				Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
				onClicked: Clipboard.remove(row.modelData.line)
			}
		}
	}
}
