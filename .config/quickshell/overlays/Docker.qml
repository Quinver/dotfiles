import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Docker overlay (Ui.overlay === "docker"): one tab per container host (this PC, ssh hosts)
// plus "Virtual machines". Rows are grouped by compose project; every row has a fixed-width
// action strip that is always laid out (dimmed until the row is hovered or selected), and
// hover comes from a HoverHandler so it survives the pointer entering a child button.
// Keys: Up/Down/W/S/J/K move, Left/Right/H/L/Tab/Shift+Tab or 1-9 switch tab, Enter logs
// (VM: console), E shell, Shift+S or Space start/stop, R restart (stop/restart/shutdown ask
// for a second press within 3 s), / filter, Esc/Q close. Data comes from services/Containers.qml,
// which only polls while this overlay holds a watcher.
LazyLoader {
	active: Ui.overlay === "docker"

	PanelWindow {
		id: win
		screen: Ui.overlayScreen
		WlrLayershell.layer: WlrLayer.Overlay
		WlrLayershell.namespace: "qs-docker"
		WlrLayershell.keyboardFocus: Ui.testMode ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
		exclusionMode: ExclusionMode.Ignore
		anchors { top: true; bottom: true; left: true; right: true }
		color: Qt.rgba(0, 0, 0, 0.35)

		readonly property int rowH: Theme.rowHeight
		readonly property int groupH: 28
		readonly property int wName: 200
		readonly property int wImage: 160
		readonly property int wStatus: 150
		readonly property int wIcon: 36
		readonly property int wWide: 84
		readonly property int stripW: wIcon * 2 + wWide * 2 + Theme.spacing * 3

		property int sel: -1
		property string selKey: ""
		property string confirmKey: ""
		property string filterText: ""
		property point lastHover: Qt.point(-10, -10)

		Component.onCompleted: { Containers.watchers++; focusKeys(); }
		Component.onDestruction: Containers.watchers--;
		onVisibleChanged: if (visible) focusKeys()
		onWindowConnected: focusKeys()
		function focusKeys() { keys.forceActiveFocus(); }

		Timer { id: confirmTimer; interval: 3000; onTriggered: win.confirmKey = "" }

		// ---- tabs ----
		readonly property var tabs: {
			var out = Containers.hosts.map(h => ({ name: h.name, label: h.ssh ? h.name : "This PC", vm: false }));
			if (Containers.hasVms) out.push({ name: "Virtual machines", label: "Virtual machines", vm: true });
			return out;
		}
		readonly property int tabIdx: Math.max(0, tabs.findIndex(t => t.name === Containers.lastTab))
		readonly property var tab: tabs[tabIdx]
		function setTab(i) {
			i = (i + tabs.length) % tabs.length;
			Containers.lastTab = tabs[i].name;
			filterText = ""; filter.text = "";
			sel = -1; selKey = ""; confirmKey = "";
		}
		function tabInfo(t) {
			if (t.vm) {
				var vr = Containers.vms.filter(v => vmRunning(v)).length;
				return { ok: !Containers.vmError, count: Containers.vmError ? "" : vr + "/" + Containers.vms.length };
			}
			var st = Containers.stateOf(t.name);
			var run = st.containers.filter(c => c.state === "running").length;
			return { ok: st.status !== "unreachable", count: st.status === "ok" ? run + "/" + st.containers.length : "" };
		}

		// ---- rows of the current tab ----
		readonly property var hostState: tab.vm ? null : Containers.stateOf(tab.name)
		readonly property string message: {
			if (tab.vm) return Containers.vmError ? "libvirt is unavailable" : Containers.vms.length === 0 ? "No virtual machines" : "";
			if (hostState.status === "loading") return "Loading…";
			if (hostState.status === "unreachable") return "Host unreachable" + (hostState.error ? "  -  " + hostState.error : "");
			return hostState.containers.length === 0 ? "No containers" : "";
		}
		readonly property var rows: {
			var q = filterText.trim().toLowerCase();
			var out = [];
			if (tab.vm) {
				Containers.vms.forEach(v => { if (!q || v.name.toLowerCase().indexOf(q) >= 0) out.push({ kind: "vm", key: "vm|" + v.name, vm: v }); });
				return out;
			}
			var cs = hostState.containers.filter(c => !q || (c.name + " " + c.image + " " + c.project).toLowerCase().indexOf(q) >= 0);
			// only compose projects with 2+ containers get a header; single ones go to one plain list
			var counts = {};
			cs.forEach(c => { if (c.project) counts[c.project] = (counts[c.project] || 0) + 1; });
			const proj = c => counts[c.project] > 1 ? c.project : "";
			var projects = Object.keys(counts).filter(k => counts[k] > 1).sort();
			var groups = projects.concat([""]);
			for (var g = 0; g < groups.length; g++) {
				var members = cs.filter(c => proj(c) === groups[g]).sort((a, b) => a.name.localeCompare(b.name));
				if (!members.length) continue;
				if (projects.length) out.push({ kind: "group", key: "g|" + groups[g], text: groups[g] || "containers", count: members.length });
				members.forEach(c => out.push({ kind: "c", key: "c|" + c.name, host: tab.name, c: c }));
			}
			return out;
		}
		readonly property int total: tab.vm ? Containers.vms.length : hostState.containers.length
		readonly property int running: tab.vm ? Containers.vms.filter(v => vmRunning(v)).length : hostState.containers.filter(c => c.state === "running").length
		readonly property var cur: sel >= 0 && sel < rows.length ? rows[sel] : null

		function selectable(i) { return i >= 0 && i < rows.length && rows[i].kind !== "group"; }
		onRowsChanged: {
			var i = rows.findIndex(r => r.key === selKey);
			if (i < 0) {
				i = -1;
				for (var n = 0; n < rows.length; n++) if (selectable(n)) { i = n; break; }
				selKey = i >= 0 ? rows[i].key : "";
			}
			sel = i;
		}
		function select(i) { if (selectable(i)) { sel = i; selKey = rows[i].key; list.positionViewAtIndex(i, ListView.Contain); } }
		function move(d) {
			for (var i = sel + d; i >= 0 && i < rows.length; i += d) if (selectable(i)) { select(i); return; }
		}

		// ---- actions ----
		function isRunning(c) { return c.state === "running" || c.state === "restarting" || c.state === "paused"; }
		function vmRunning(v) { return v.state === "running" || v.state === "idle" || v.state === "paused"; }
		function ckey(verb, r) { return verb + "|" + (r.kind === "vm" ? r.vm.name : r.host + "|" + r.c.name); }
		function ask(verb, r) {
			var key = ckey(verb, r);
			if (confirmKey !== key) { confirmKey = key; confirmTimer.restart(); return false; }
			confirmKey = "";
			return true;
		}
		function toggle(r) {
			if (r.kind === "vm") {
				if (!vmRunning(r.vm)) Containers.vmStart(r.vm.name);
				else if (ask("shutdown", r)) Containers.vmShutdown(r.vm.name);
			} else if (!isRunning(r.c)) Containers.start(r.host, r.c);
			else if (ask("stop", r)) Containers.stop(r.host, r.c);
		}
		function restart(r) { if (r.kind === "c" && ask("restart", r)) Containers.restart(r.host, r.c); }
		function logs(r) { if (r.kind === "vm") Containers.openVm(r.vm.name); else Containers.openLogs(r.host, r.c); }
		function shell(r) { if (r.kind === "c") Containers.openShell(r.host, r.c); }
		function shortPorts(p) {
			return (p || "").split(", ").filter(x => x && x.indexOf(":::") !== 0 && x.indexOf("[::]") !== 0).map(x => x.replace(/^0\.0\.0\.0:/, "")).join("  ");
		}

		MouseArea { anchors.fill: parent; onClicked: Ui.close() }

		// Small action button with a fixed width; `armed` = waiting for confirmation.
		component Act: Item {
			id: act
			property string glyph: ""
			property string label: ""
			property bool armed: false
			property bool strong: false     // row is hovered / selected
			signal clicked()
			implicitHeight: 28
			opacity: strong ? 1 : 0.4
			Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
			Rectangle {
				anchors.fill: parent
				radius: Theme.roundingSmall
				color: act.armed ? Theme.warn : ma.containsMouse ? Theme.surfaceTop : Theme.surfaceHi
				border.width: Theme.border
				border.color: act.armed ? Theme.warn : Theme.outlineDim
				Behavior on color { ColorAnimation { duration: Theme.animFast } }
			}
			Row {
				anchors.centerIn: parent
				spacing: 6
				Icon { visible: !act.armed; glyph: act.glyph; size: Theme.fontSmall + 2; color: Theme.fg; anchors.verticalCenter: parent.verticalCenter }
				Txt { visible: act.label !== "" || act.armed; text: act.armed ? "Confirm?" : act.label; size: Theme.fontSmall; color: act.armed ? Theme.bg : Theme.fg; anchors.verticalCenter: parent.verticalCenter }
			}
			MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: act.clicked() }
		}

		Box {
			id: panel
			width: Math.min(960, win.width - Theme.gap * 2)
			height: Math.min(780, win.height * 0.8)
			anchors.centerIn: parent

			MouseArea { anchors.fill: parent }

			Item {
				id: keys
				anchors.fill: parent
				focus: true
				Keys.onPressed: function (ev) {
					var k = ev.key, shift = ev.modifiers & Qt.ShiftModifier, r = win.cur;
					if (k === Qt.Key_Escape || k === Qt.Key_Q) Ui.close();
					else if (k === Qt.Key_Up || k === Qt.Key_K || k === Qt.Key_W) win.move(-1);
					else if (k === Qt.Key_Down || k === Qt.Key_J || (k === Qt.Key_S && !shift)) win.move(1);
					else if (k === Qt.Key_Left || k === Qt.Key_H || k === Qt.Key_A || k === Qt.Key_Backtab) win.setTab(win.tabIdx - 1);
					else if (k === Qt.Key_Right || k === Qt.Key_L || k === Qt.Key_D || k === Qt.Key_Tab) win.setTab(win.tabIdx + 1);
					else if (k >= Qt.Key_1 && k <= Qt.Key_9) { if (k - Qt.Key_1 < win.tabs.length) win.setTab(k - Qt.Key_1); }
					else if (k === Qt.Key_Slash) filter.focusInput();
					else if (!r) return;
					else if (k === Qt.Key_Return || k === Qt.Key_Enter) win.logs(r);
					else if (k === Qt.Key_S || k === Qt.Key_Space) win.toggle(r);
					else if (k === Qt.Key_R) win.restart(r);
					else if (k === Qt.Key_E) win.shell(r);
					else return;
					ev.accepted = true;
				}
			}

			Column {
				x: Theme.pad
				y: Theme.pad
				width: parent.width - Theme.pad * 2
				height: parent.height - Theme.pad * 2
				spacing: Theme.spacing

				// ---- tab bar ----
				Row {
					id: tabBar
					width: parent.width
					spacing: Theme.spacing
					Repeater {
						model: win.tabs
						delegate: Item {
							id: tb
							required property var modelData
							required property int index
							readonly property bool active: win.tabIdx === index
							readonly property var info: win.tabInfo(modelData)
							width: (tabBar.width - tabBar.spacing * (win.tabs.length - 1)) / win.tabs.length
							height: Theme.rowHeight + 8

							Rectangle {
								anchors.fill: parent
								radius: Theme.rounding
								color: tb.active ? Theme.alpha(Theme.primary, 0.2) : hh.hovered ? Theme.surfaceHi : Theme.surface
								border.width: Math.max(Theme.border, 1)
								border.color: tb.active ? Theme.primary : Theme.outlineDim
								Behavior on color { ColorAnimation { duration: Theme.animFast } }
							}
							Row {
								anchors.centerIn: parent
								spacing: Theme.pad
								Rectangle { width: 9; height: 9; anchors.verticalCenter: parent.verticalCenter; color: tb.info.ok ? Theme.ok : Theme.error }
								Txt { text: tb.modelData.label; bold: tb.active; color: tb.active ? Theme.primary : Theme.fg; anchors.verticalCenter: parent.verticalCenter }
								Txt { text: tb.info.count; mono: true; size: Theme.fontSmall; muted: true; anchors.verticalCenter: parent.verticalCenter }
							}
							HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
							TapHandler { onTapped: { win.setTab(tb.index); win.focusKeys(); } }
						}
					}
				}

				// ---- filter + summary ----
				Row {
					width: parent.width
					spacing: Theme.spacing
					Field {
						id: filter
						width: parent.width - summary.width - Theme.spacing
						icon: Icons.search
						placeholder: win.tab.vm ? "Filter virtual machines" : "Filter by name, image or project"
						onEdited: function (t) { win.filterText = t; }
						onAccepted: win.focusKeys()
						input.Keys.onPressed: function (ev) {
							var k = ev.key;
							if (k === Qt.Key_Escape) { filter.text = ""; win.filterText = ""; win.focusKeys(); }
							else if (k === Qt.Key_Down) { win.move(1); win.focusKeys(); }
							else if (k === Qt.Key_Up) { win.move(-1); win.focusKeys(); }
							else return;
							ev.accepted = true;
						}
					}
					Txt {
						id: summary
						width: 150
						height: filter.height
						horizontalAlignment: Text.AlignRight
						rightPadding: Theme.spacing
						text: win.running + " running / " + win.total
						mono: true
						size: Theme.fontSmall
						dim: true
					}
				}

				// ---- column header ----
				Item {
					id: head
					width: parent.width
					height: Theme.rowHeight - 8
					visible: win.message === ""
					readonly property int x0: Theme.pad + 8 + Theme.pad
					Txt { x: head.x0; width: win.wName; height: head.height; text: win.tab.vm ? "Name" : "Container"; size: Theme.fontSmall; muted: true }
					Txt { x: head.x0 + win.wName; width: win.wImage; height: head.height; text: win.tab.vm ? "" : "Image"; size: Theme.fontSmall; muted: true }
					Txt { x: head.x0 + win.wName + win.wImage; width: win.wStatus; height: head.height; text: win.tab.vm ? "State" : "Status"; size: Theme.fontSmall; muted: true }
					Txt { x: head.x0 + win.wName + win.wImage + win.wStatus; width: head.width - x - win.stripW - Theme.pad * 2; height: head.height; text: win.tab.vm ? "" : "Ports"; size: Theme.fontSmall; muted: true }
				}
				Sep { width: parent.width }

				// ---- list ----
				Item {
					width: parent.width
					height: parent.height - y - hint.height - Theme.spacing * 2

					Column {
						anchors.centerIn: parent
						visible: win.message !== ""
						spacing: Theme.pad
						Txt { anchors.horizontalCenter: parent.horizontalCenter; text: win.message; muted: true }
						Btn {
							visible: !win.tab.vm && win.hostState.status === "unreachable"
							anchors.horizontalCenter: parent.horizontalCenter
							icon: Icons.refresh
							text: "Retry"
							onClicked: { Containers.refreshHost(win.tab.name); win.focusKeys(); }
						}
					}
					Txt {
						anchors.centerIn: parent
						visible: win.message === "" && win.rows.length === 0
						muted: true
						text: "Nothing matches the filter"
					}

					ListView {
						id: list
						anchors.fill: parent
						visible: win.message === ""
						clip: true
						model: win.rows
						boundsBehavior: Flickable.StopAtBounds
						spacing: 2

						delegate: Item {
							id: row
							required property var modelData
							required property int index
							readonly property var r: modelData
							readonly property bool isGroup: r.kind === "group"
							readonly property bool isVm: r.kind === "vm"
							readonly property bool selected: win.sel === index
							readonly property bool strong: !isGroup && (selected || hh.hovered)
							readonly property bool up: isGroup ? false : isVm ? win.vmRunning(r.vm) : win.isRunning(r.c)
							width: ListView.view.width
							height: isGroup ? win.groupH : win.rowH

							Txt {
								visible: row.isGroup
								anchors { left: parent.left; leftMargin: Theme.pad; right: parent.right; bottom: parent.bottom; bottomMargin: 2 }
								text: row.isGroup ? row.r.text + "  (" + row.r.count + ")" : ""
								size: Theme.fontSmall
								bold: true
								color: Theme.primary
							}

							Item {
								visible: !row.isGroup
								anchors.fill: parent

								Rectangle {
									anchors.fill: parent
									radius: Theme.roundingSmall
									color: row.selected ? Theme.surfaceTop : hh.hovered ? Theme.surfaceHi : "transparent"
									border.width: row.selected ? Math.max(Theme.border, 1) : 0
									border.color: Theme.primary
									Behavior on color { ColorAnimation { duration: Theme.animFast } }
								}

								Rectangle {
									id: dot
									x: Theme.pad
									anchors.verticalCenter: parent.verticalCenter
									width: 8; height: 8
									color: !row.up ? Theme.fgMuted : (!row.isVm && row.r.c.state !== "running") ? Theme.warn : Theme.ok
								}
								Txt {
									x: head.x0; width: win.wName - Theme.pad; height: parent.height
									text: row.isVm ? row.r.vm.name : row.isGroup ? "" : row.r.c.name
									bold: row.up
									color: row.selected ? Theme.primary : Theme.fg
								}
								Txt {
									x: head.x0 + win.wName; width: win.wImage - Theme.pad; height: parent.height
									visible: !row.isVm
									text: row.isVm || row.isGroup ? "" : row.r.c.image.replace(/^.*\//, "")
									size: Theme.fontSmall; muted: true
								}
								Txt {
									x: head.x0 + win.wName + win.wImage; width: win.wStatus - Theme.pad; height: parent.height
									text: row.isVm ? row.r.vm.state : row.isGroup ? "" : row.r.c.status.replace(/^Up /, "up ").replace(/^Exited \(\d+\) /, "exited ").replace(/ ago$/, "")
									mono: true; size: Theme.fontSmall; dim: true
								}
								Txt {
									x: head.x0 + win.wName + win.wImage + win.wStatus
									width: strip.x - x - Theme.pad
									height: parent.height
									visible: !row.isVm
									text: row.isVm || row.isGroup ? "" : win.shortPorts(row.r.c.ports)
									mono: true; size: Theme.fontSmall; muted: true
								}

								// Always laid out; only the opacity changes with hover/selection.
								Row {
									id: strip
									width: win.stripW
									anchors { right: parent.right; rightMargin: Theme.spacing; verticalCenter: parent.verticalCenter }
									spacing: Theme.spacing
									layoutDirection: Qt.LeftToRight

									Act {
										width: win.wIcon; strong: row.strong
										glyph: row.isVm ? Icons.desktop : Icons.listView
										onClicked: { win.select(row.index); win.logs(row.r); }
									}
									Act {
										width: win.wIcon; strong: row.strong
										glyph: Icons.terminal
										opacity: row.isVm ? 0 : (strong ? 1 : 0.4)
										enabled: !row.isVm
										onClicked: { win.select(row.index); win.shell(row.r); }
									}
									Act {
										width: win.wWide; strong: row.strong
										glyph: Icons.refresh; label: "Restart"
										opacity: row.isVm ? 0 : (strong ? 1 : 0.4)
										enabled: !row.isVm
										armed: !row.isGroup && !row.isVm && win.confirmKey === win.ckey("restart", row.r)
										onClicked: { win.select(row.index); win.restart(row.r); }
									}
									Act {
										width: win.wWide; strong: row.strong
										glyph: row.up ? Icons.stop : Icons.play
										label: row.up ? (row.isVm ? "Shutdown" : "Stop") : "Start"
										armed: !row.isGroup && win.confirmKey === win.ckey(row.isVm ? "shutdown" : "stop", row.r)
										onClicked: { win.select(row.index); win.toggle(row.r); }
									}
								}

								// Passive: keeps hovering while the pointer is over a child button.
								HoverHandler {
									id: hh
									onPointChanged: {
										var g = row.mapToItem(null, point.position.x, point.position.y);
										if (Math.abs(g.x - win.lastHover.x) + Math.abs(g.y - win.lastHover.y) < 3) return;
										win.lastHover = Qt.point(g.x, g.y);
										win.select(row.index);
									}
								}
								TapHandler {
									gesturePolicy: TapHandler.DragThreshold
									onTapped: { win.select(row.index); win.focusKeys(); }
								}
							}
						}
					}
				}

				Txt {
					id: hint
					width: parent.width
					height: implicitHeight
					text: "Up/Down move   Left/Right or 1-9 tab   Enter logs   E shell   Space start/stop   R restart   / filter   Esc close"
					size: Theme.fontSmall
					muted: true
					horizontalAlignment: Text.AlignHCenter
				}
			}
		}
	}
}
