import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Task manager overlay (Ui.overlay === "tasks"): live CPU/RAM/GPU/temperature graphs,
// a sortable, filterable, optionally grouped process table, and kill with confirmation.
// Keys: Up/Down/W/S/J/K move, PgUp/PgDn, Home/End, Left/Right or 1-5 sort column,
// G group by name, / or typing filter, Shift+K or Delete end process (then Enter =
// terminate, Shift+Enter = force kill, Esc = cancel), Esc/Q close. Sampling runs only
// while the overlay is open (services/Procs.qml).
LazyLoader {
	active: Ui.overlay === "tasks"

	PanelWindow {
		id: win
		screen: Ui.overlayScreen
		WlrLayershell.layer: WlrLayer.Overlay
		WlrLayershell.namespace: "qs-tasks"
		WlrLayershell.keyboardFocus: Ui.testMode ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
		exclusionMode: ExclusionMode.Ignore
		anchors { top: true; bottom: true; left: true; right: true }
		color: Qt.rgba(0, 0, 0, 0.35)

		readonly property var cols: ["name", "pid", "cpu", "mem", "gpu", "user"]
		readonly property var sortCols: ["name", "pid", "cpu", "mem", "gpu"]
		readonly property int wPid: 70
		readonly property int wCpu: 100
		readonly property int wMem: 110
		readonly property int wGpu: 70
		readonly property int wUser: 100
		readonly property int rowH: Theme.rowHeight - 6

		readonly property var rows: Procs.rows
		property string selKey: ""
		property int sel: 0
		property var confirm: null          // { name, pids, label }
		property string note: ""
		property point lastHover: Qt.point(-10, -10)
		readonly property var cur: rows[sel] || null

		// Keep the selection on the same process across refreshes.
		onRowsChanged: {
			var i = rows.findIndex(r => r.key === selKey);
			if (i < 0) {
				i = Math.max(0, Math.min(sel, rows.length - 1));
				selKey = rows[i] ? rows[i].key : "";
			}
			sel = i;
		}
		onSelChanged: list.positionViewAtIndex(sel, ListView.Contain)

		function select(i) {
			if (rows.length === 0) return;
			sel = Math.max(0, Math.min(rows.length - 1, i));
			selKey = rows[sel].key;
		}
		function page() { return Math.max(1, Math.floor(list.height / rowH) - 1); }
		function sortBy(i) { Procs.setSort(sortCols[Math.max(0, Math.min(sortCols.length - 1, i))]); }
		function shiftSort(d) { sortBy(sortCols.indexOf(Procs.sortKey) + d); }
		function say(t) { note = t; noteTimer.restart(); }

		function askEnd() {
			var r = cur;
			if (!r) return;
			if (!r.mine) { say("That one belongs to " + r.user + " - only your own processes can be ended."); return; }
			var mineCount = r.count; // group rows end only the user's own members (see Procs.kill)
			confirm = { name: r.name, pids: r.pids, label: r.pid > 0 ? r.name + " (" + r.pid + ")" : r.name + " (" + mineCount + " processes)" };
		}
		function doEnd(force) {
			var n = Procs.kill(confirm.pids, force);
			say(n > 0 ? (force ? "Force killed " : "Asked to end ") + confirm.name : "Nothing to end");
			confirm = null;
		}

		function focusKeys() { keys.forceActiveFocus(); }
		Component.onCompleted: focusKeys()
		onVisibleChanged: if (visible) focusKeys()
		onWindowConnected: focusKeys()

		Timer { id: noteTimer; interval: 3500; onTriggered: win.note = "" }

		MouseArea { anchors.fill: parent; onClicked: Ui.close() }

		Box {
			id: panel
			width: Math.min(960, win.width - Theme.gap * 2)
			height: Math.min(780, win.height * 0.9)
			anchors.centerIn: parent

			MouseArea { anchors.fill: parent }

			Item {
				id: keys
				anchors.fill: parent
				focus: true
				Keys.onPressed: function (ev) {
					var k = ev.key, shift = ev.modifiers & Qt.ShiftModifier;
					if (win.confirm) {
						if (k === Qt.Key_Return || k === Qt.Key_Enter) win.doEnd(!!shift);
						else if (k === Qt.Key_Escape) win.confirm = null;
						ev.accepted = true;
						return;
					}
					if (k === Qt.Key_Escape || k === Qt.Key_Q) Ui.close();
					else if (k === Qt.Key_Delete || (k === Qt.Key_K && shift)) win.askEnd();
					else if (k === Qt.Key_Up || k === Qt.Key_W || k === Qt.Key_K) win.select(win.sel - 1);
					else if (k === Qt.Key_Down || k === Qt.Key_S || k === Qt.Key_J) win.select(win.sel + 1);
					else if (k === Qt.Key_PageUp) win.select(win.sel - win.page());
					else if (k === Qt.Key_PageDown) win.select(win.sel + win.page());
					else if (k === Qt.Key_Home) win.select(0);
					else if (k === Qt.Key_End) win.select(win.rows.length - 1);
					else if (k === Qt.Key_Left || k === Qt.Key_A || k === Qt.Key_H) win.shiftSort(-1);
					else if (k === Qt.Key_Right || k === Qt.Key_D || k === Qt.Key_L) win.shiftSort(1);
					else if (k >= Qt.Key_1 && k <= Qt.Key_5) win.sortBy(k - Qt.Key_1);
					else if (k === Qt.Key_G) Procs.grouped = !Procs.grouped;
					else if (k === Qt.Key_Slash) filter.focusInput();
					else if (ev.text.length === 1 && ev.text >= " " && !(ev.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
						filter.focusInput();
						filter.input.text += ev.text;
						filter.input.cursorPosition = filter.input.text.length;
						Procs.filter = filter.text;
					}
					else return;
					ev.accepted = true;
				}
			}

			Column {
				id: col
				x: Theme.pad
				y: Theme.pad
				width: parent.width - Theme.pad * 2
				height: parent.height - Theme.pad * 2
				spacing: Theme.spacing

				// ---- graphs ----
				Row {
					id: graphs
					width: parent.width
					spacing: Theme.spacing
					readonly property real cw: (width - spacing * 3) / 4

					Repeater {
						model: [
							{ title: "CPU", icon: Icons.cpu, val: Math.round(SysInfo.cpu * 100) + "%", hist: SysInfo.cpuHistory, max: 1, sub: SysInfo.cpuThreads + " threads" },
							{ title: "RAM", icon: Icons.memory, val: Math.round(SysInfo.mem * 100) + "%", hist: SysInfo.memHistory, max: 1, sub: SysInfo.fmtBytes(SysInfo.memUsed) + " / " + SysInfo.fmtBytes(SysInfo.memTotal) },
							{ title: "GPU", icon: Icons.chip, val: Math.round(SysInfo.gpu * 100) + "%", hist: SysInfo.gpuHistory, max: 1, sub: SysInfo.fmtBytes(SysInfo.vramUsed) + " / " + SysInfo.fmtBytes(SysInfo.vramTotal) + " VRAM" },
							{ title: "Temp", icon: Icons.gauge, val: Math.round(SysInfo.cpuTemp) + " / " + Math.round(SysInfo.gpuTemp) + "°", hist: Procs.cpuTempHistory, hist2: Procs.gpuTempHistory, max: 100, sub: "CPU / GPU" }
						]
						delegate: Box {
							id: cell
							required property var modelData
							width: graphs.cw
							height: 96
							level: 2
							small: true

							Row {
								x: Theme.pad
								y: Theme.spacing
								spacing: Theme.spacing
								Icon { glyph: cell.modelData.icon; color: Theme.primary }
								Txt { text: cell.modelData.title; dim: true; size: Theme.fontSmall }
							}
							Txt {
								anchors { top: parent.top; right: parent.right; topMargin: Theme.spacing - 2; rightMargin: Theme.pad }
								text: cell.modelData.val
								mono: true
								bold: true
							}
							Graph {
								x: Theme.pad
								y: 28
								width: parent.width - Theme.pad * 2
								height: 40
								values: cell.modelData.hist
								max: cell.modelData.max
							}
							Graph {
								x: Theme.pad
								y: 28
								width: parent.width - Theme.pad * 2
								height: 40
								visible: !!cell.modelData.hist2
								filled: false
								line: Theme.tertiary
								values: cell.modelData.hist2 || []
								max: cell.modelData.max
							}
							Txt {
								anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: Theme.pad; rightMargin: Theme.pad; bottomMargin: 4 }
								text: cell.modelData.sub
								size: Theme.fontSmall
								muted: true
							}
						}
					}
				}

				// ---- filter + mode ----
				Row {
					width: parent.width
					spacing: Theme.spacing

					Field {
						id: filter
						width: parent.width - groupBtn.width - Theme.spacing
						icon: Icons.search
						placeholder: "Filter by name, user or pid"
						onEdited: Procs.filter = text
						onAccepted: win.focusKeys()
						input.Keys.onPressed: function (ev) {
							var k = ev.key;
							if (k === Qt.Key_Escape) { filter.text = ""; Procs.filter = ""; win.focusKeys(); }
							else if (k === Qt.Key_Down) win.select(win.sel + 1);
							else if (k === Qt.Key_Up) win.select(win.sel - 1);
							else if (k === Qt.Key_PageDown) win.select(win.sel + win.page());
							else if (k === Qt.Key_PageUp) win.select(win.sel - win.page());
							else return;
							ev.accepted = true;
						}
					}
					Btn {
						id: groupBtn
						text: Procs.grouped ? "Grouped by name" : "Group by name"
						icon: Icons.listView
						flat: !Procs.grouped
						onClicked: { Procs.grouped = !Procs.grouped; win.focusKeys(); }
					}
				}

				// ---- table header ----
				Item {
					id: head
					width: parent.width
					height: Theme.rowHeight - 8

					Repeater {
						model: win.cols
						delegate: Item {
							id: hc
							required property string modelData
							readonly property bool sorted: Procs.sortKey === modelData
							readonly property bool alignRight: modelData === "cpu" || modelData === "mem" || modelData === "gpu" || modelData === "pid"
							height: head.height
							width: modelData === "name" ? 120 : win.colW(modelData)
							x: modelData === "name" ? Theme.pad : head.width - win.rightOffset(modelData) - width
							Txt {
								anchors.fill: parent
								anchors.rightMargin: hc.alignRight ? Theme.spacing : 0
								horizontalAlignment: hc.alignRight ? Text.AlignRight : Text.AlignLeft
								text: win.colTitle(hc.modelData) + (hc.sorted ? (Procs.sortDesc ? " ▾" : " ▴") : "")
								size: Theme.fontSmall
								bold: hc.sorted
								color: hc.sorted ? Theme.primary : hc.hovered ? Theme.fg : Theme.fgMuted
							}
							property bool hovered: hm.containsMouse
							MouseArea {
								id: hm
								anchors.fill: parent
								enabled: hc.modelData !== "user"
								hoverEnabled: true
								onClicked: { Procs.setSort(hc.modelData); win.focusKeys(); }
							}
						}
					}
				}
				Sep { width: parent.width }

				// ---- table ----
				ListView {
					id: list
					width: parent.width
					height: parent.height - y - strip.height - hint.height - Theme.spacing * 2
					clip: true
					model: win.rows
					boundsBehavior: Flickable.StopAtBounds

					Txt {
						anchors.centerIn: parent
						visible: list.count === 0
						muted: true
						text: Procs.procs.length === 0 ? "Reading processes..." : "No processes match"
					}

					delegate: Item {
						id: row
						required property var modelData
						required property int index
						readonly property var r: modelData
						readonly property bool selected: win.sel === index
						width: ListView.view.width
						height: win.rowH
						opacity: r.mine ? 1 : 0.55

						Rectangle {
							anchors.fill: parent
							radius: Theme.roundingSmall
							color: row.selected ? Theme.surfaceTop : rowMouse.containsMouse ? Theme.surfaceHi : "transparent"
							border.width: row.selected ? Math.max(Theme.border, 1) : 0
							border.color: Theme.primary
							Behavior on color { ColorAnimation { duration: Theme.animFast } }
						}

						// bars behind the numeric columns
						Rectangle {
							x: row.width - win.rightOffset("cpu") - win.wCpu + Theme.spacing
							anchors.verticalCenter: parent.verticalCenter
							height: parent.height - 8
							width: (win.wCpu - Theme.spacing * 2) * Math.min(1, row.r.cpu / Procs.maxCpu)
							color: Theme.alpha(Theme.primary, 0.28)
						}
						Rectangle {
							x: row.width - win.rightOffset("mem") - win.wMem + Theme.spacing
							anchors.verticalCenter: parent.verticalCenter
							height: parent.height - 8
							width: (win.wMem - Theme.spacing * 2) * Math.min(1, row.r.mem / Procs.maxMem)
							color: Theme.alpha(Theme.primary, 0.28)
						}

						Txt {
							x: Theme.pad
							width: row.width - win.rightOffset("pid") - win.wPid - Theme.pad - Theme.spacing
							height: parent.height
							text: row.r.name
							color: row.selected ? Theme.primary : Theme.fg
						}
						Repeater {
							model: ["pid", "cpu", "mem", "gpu", "user"]
							delegate: Txt {
								required property string modelData
								x: row.width - win.rightOffset(modelData) - width
								width: win.colW(modelData)
								height: row.height
								rightPadding: modelData === "user" ? 0 : Theme.spacing
								horizontalAlignment: modelData === "user" ? Text.AlignLeft : Text.AlignRight
								mono: modelData !== "user"
								dim: modelData === "pid" || modelData === "user"
								text: win.cellText(row.r, modelData)
							}
						}

						MouseArea {
							id: rowMouse
							anchors.fill: parent
							hoverEnabled: true
							onPositionChanged: function (m) {
								var g = rowMouse.mapToItem(null, m.x, m.y);
								if (Math.abs(g.x - win.lastHover.x) + Math.abs(g.y - win.lastHover.y) < 3) return;
								win.lastHover = Qt.point(g.x, g.y);
								win.select(row.index);
							}
							onClicked: { win.select(row.index); win.focusKeys(); }
						}
					}
				}

				// ---- confirm / note strip ----
				Item {
					id: strip
					width: parent.width
					height: win.confirm || win.note !== "" ? Theme.rowHeight : 0
					clip: true
					Behavior on height { NumberAnimation { duration: Theme.animFast } }

					Rectangle {
						anchors.fill: parent
						radius: Theme.roundingSmall
						color: win.confirm ? Theme.alpha(Theme.error, 0.18) : Theme.surfaceTop
						border.width: Math.max(Theme.border, 1)
						border.color: win.confirm ? Theme.error : Theme.outlineDim
					}
					Txt {
						anchors.fill: parent
						anchors.leftMargin: Theme.pad
						anchors.rightMargin: Theme.pad
						text: win.confirm
							? "End " + win.confirm.label + "?  Enter = terminate, Shift+Enter = force kill, Esc = cancel"
							: win.note
						color: win.confirm ? Theme.fg : Theme.fgDim
					}
				}

				Txt {
					id: hint
					width: parent.width
					height: implicitHeight
					text: "Up/Down move   1-5 sort   G group   / filter   Shift+K end process   Esc close"
					size: Theme.fontSmall
					muted: true
					horizontalAlignment: Text.AlignHCenter
				}
			}
		}

		function colW(c) { return c === "pid" ? wPid : c === "cpu" ? wCpu : c === "mem" ? wMem : c === "gpu" ? wGpu : c === "user" ? wUser : 0; }
		// Distance from the row's right edge to the right edge of a column.
		function rightOffset(c) {
			var order = ["user", "gpu", "mem", "cpu", "pid"], off = 0;
			for (var i = 0; i < order.length && order[i] !== c; i++) off += colW(order[i]);
			return off;
		}
		function colTitle(c) { return c === "pid" ? (Procs.grouped ? "Count" : "PID") : c === "cpu" ? "CPU" : c === "mem" ? "Memory" : c === "gpu" ? "GPU" : c === "user" ? "User" : "Name"; }
		function cellText(r, c) {
			if (c === "pid") return r.pid > 0 ? String(r.pid) : String(r.count);
			if (c === "cpu") return r.cpu.toFixed(1) + "%";
			if (c === "mem") return SysInfo.fmtBytes(r.mem);
			if (c === "gpu") return r.gpu > 0 ? r.gpu + "%" : r.vram > 0 ? SysInfo.fmtBytes(r.vram) : "-";
			return r.user;
		}
	}
}
