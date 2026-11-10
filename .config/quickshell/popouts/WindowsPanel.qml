import QtQuick
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.widgets

// All open windows grouped by workspace. Click focuses, the close button closes.
Item {
	id: root
	implicitWidth: Theme.popoutWidth

	// Flat model: header rows and window rows, ordered by workspace id.
	readonly property var rows: {
		void Windows.rev;
		var out = [];
		var wss = Hyprland.workspaces.values.slice().sort((a, b) => a.id - b.id);
		wss.forEach(ws => {
			var wins = Windows.windowsOn(ws.id);
			if (wins.length === 0) return;
			out.push({ header: true, title: (ws.id < 0 ? ws.name : "Workspace " + ws.id) + (ws.monitor ? " · " + ws.monitor.name : "") });
			wins.forEach(w => out.push({ header: false, win: w }));
		});
		return out;
	}

	implicitHeight: rows.length === 0 ? Theme.rowHeight : Math.min(list.contentHeight, 420)

	Txt {
		visible: root.rows.length === 0
		anchors.centerIn: parent
		text: "No open windows"
		muted: true
	}

	ListView {
		id: list
		anchors.fill: parent
		clip: true
		model: root.rows
		boundsBehavior: Flickable.StopAtBounds

		delegate: Item {
			id: row
			required property var modelData
			width: list.width
			height: modelData.header ? 28 : Theme.rowHeight + 10

			Header {
				visible: row.modelData.header
				anchors.fill: parent
				title: row.modelData.header ? row.modelData.title : ""
			}

			ListItem {
				visible: !row.modelData.header
				anchors.fill: parent
				title: row.modelData.header ? "" : row.modelData.win.title
				subtitle: row.modelData.header ? "" : Windows.classOf(row.modelData.win)
				selected: !row.modelData.header && row.modelData.win.activated
				onClicked: {
					if (row.modelData.win.wayland) row.modelData.win.wayland.activate();
					Ui.close();
				}
				leading: [AppIcon {
					app: row.modelData.header ? "" : Windows.classOf(row.modelData.win)
					size: 22
				}]
				Btn {
					flat: true
					icon: Icons.close
					onClicked: if (row.modelData.win.wayland) row.modelData.win.wayland.close()
				}
			}
		}
	}
}
