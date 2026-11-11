import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import qs.config
import qs.services
import qs.widgets

// Volume mixer overlay (Ui.overlay === "mixer"): output + input masters, per-app
// streams with live level meters, and device selection. Keys: Up/Down select,
// Left/Right +-5% (Shift 1%), M/Space mute, 0-9 / ` set volume, Enter default
// device, Tab next section, Esc/Q close. Meters run only while the overlay exists.
LazyLoader {
	active: Ui.overlay === "mixer"

	PanelWindow {
		id: win
		screen: Ui.overlayScreen
		WlrLayershell.layer: WlrLayer.Overlay
		WlrLayershell.namespace: "qs-mixer"
		WlrLayershell.keyboardFocus: Ui.testMode ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
		exclusionMode: ExclusionMode.Ignore
		anchors { top: true; bottom: true; left: true; right: true }
		color: Qt.rgba(0, 0, 0, 0.35)

		// kinds: header, empty, vol (node with audio), dev (device to pick)
		readonly property var rows: {
			var r = [];
			function hdr(t) { r.push({ kind: "header", title: t, sec: -1 }); }
			function empty(t, s) { r.push({ kind: "empty", text: t, sec: s }); }
			hdr("Output");
			if (Audio.sink) r.push({ kind: "vol", node: Audio.sink, master: true, mic: false, sec: 0 });
			Audio.streams.forEach(n => r.push({ kind: "vol", node: n, master: false, mic: false, sec: 0 }));
			if (Audio.streams.length === 0) empty("no apps playing audio", 0);
			hdr("Input");
			if (Audio.source) r.push({ kind: "vol", node: Audio.source, master: true, mic: true, sec: 1 });
			Audio.inStreams.forEach(n => r.push({ kind: "vol", node: n, master: false, mic: true, sec: 1 }));
			if (Audio.inStreams.length === 0) empty("no apps recording", 1);
			hdr("Devices");
			Audio.sinks.forEach(n => r.push({ kind: "dev", node: n, mic: false, sec: 2 }));
			Audio.sources.forEach(n => r.push({ kind: "dev", node: n, mic: true, sec: 2 }));
			return r;
		}

		property int sel: 1
		property point lastHover: Qt.point(-10, -10)
		readonly property var cur: rows[sel] || null

		function selectable(i) { var r = rows[i]; return r && r.kind !== "header" && r.kind !== "empty"; }
		function move(d) {
			var i = sel;
			for (var n = 0; n < rows.length; n++) {
				i = (i + d + rows.length) % rows.length;
				if (selectable(i)) { sel = i; return; }
			}
		}
		function nextSection() {
			var s = cur ? cur.sec : -1;
			for (var i = 0; i < rows.length; i++) {
				if (selectable(i) && rows[i].sec > s) { sel = i; return; }
			}
			for (var j = 0; j < rows.length; j++) if (selectable(j)) { sel = j; return; }
		}
		onRowsChanged: {
			if (!selectable(sel)) { sel = 0; move(1); }
		}
		onSelChanged: list.positionViewAtIndex(sel, ListView.Contain)

		// Volumes may go past 100% (PipeWire software gain) up to the mixerMaxVolume option.
		readonly property real maxVol: Math.max(1, Number(Settings.opt("mixerMaxVolume", 1.5)) || 1.5)
		function audioOf(r) { return r && r.node ? r.node.audio : null; }
		function setVol(r, v) {
			var a = audioOf(r);
			if (!a) return;
			var c = Math.max(0, Math.min(win.maxVol, v));
			a.volume = c;
			if (c > 0) a.muted = false;
		}
		function nudge(d) {
			if (cur && cur.kind === "vol" && audioOf(cur)) setVol(cur, Math.round((audioOf(cur).volume + d) * 100) / 100);
		}
		function toggleMute(r) { var a = audioOf(r); if (a) a.muted = !a.muted; }
		function activate(r) {
			if (!r || r.kind !== "dev") return;
			if (r.mic) Audio.setDefaultSource(r.node); else Audio.setDefaultSink(r.node);
		}
		function isDefault(r) { return r.node === (r.mic ? Audio.source : Audio.sink); }

		Component.onCompleted: keys.forceActiveFocus()
		onVisibleChanged: if (visible) keys.forceActiveFocus()
		onWindowConnected: keys.forceActiveFocus()

		MouseArea { anchors.fill: parent; onClicked: Ui.close() }

		Box {
			id: panel
			width: 640
			height: Math.min(list.contentHeight + Theme.pad * 2 + hint.height + Theme.spacing, win.height * 0.85)
			anchors.centerIn: parent

			MouseArea { anchors.fill: parent }

			Item {
				id: keys
				anchors.fill: parent
				focus: true
				Keys.onPressed: function (ev) {
					var k = ev.key;
					var step = (ev.modifiers & Qt.ShiftModifier) ? 0.01 : 0.05;
					if (k === Qt.Key_Escape || k === Qt.Key_Q) Ui.close();
					else if (k === Qt.Key_Up || k === Qt.Key_W || k === Qt.Key_K) win.move(-1);
					else if (k === Qt.Key_Down || k === Qt.Key_S || k === Qt.Key_J) win.move(1);
					else if (k === Qt.Key_Left || k === Qt.Key_A || k === Qt.Key_H) win.nudge(-step);
					else if (k === Qt.Key_Right || k === Qt.Key_D || k === Qt.Key_L) win.nudge(step);
					else if (k === Qt.Key_Tab) win.nextSection();
					else if (k === Qt.Key_Return || k === Qt.Key_Enter) win.activate(win.cur);
					else if (k === Qt.Key_M) win.toggleMute(win.cur);
					else if (k === Qt.Key_Space) { if (win.cur && win.cur.kind === "dev") win.activate(win.cur); else win.toggleMute(win.cur); }
					else if (k >= Qt.Key_0 && k <= Qt.Key_9) { if (win.cur && win.cur.kind === "vol") win.setVol(win.cur, (k - Qt.Key_0) / 10); }
					else if (k === Qt.Key_QuoteLeft) { if (win.cur && win.cur.kind === "vol") win.setVol(win.cur, 1); }
					else return;
					ev.accepted = true;
				}
			}

			ListView {
				id: list
				x: Theme.pad
				y: Theme.pad
				width: parent.width - Theme.pad * 2
				height: parent.height - Theme.pad * 2 - hint.height - Theme.spacing
				clip: true
				model: win.rows
				boundsBehavior: Flickable.StopAtBounds
				spacing: 2

				delegate: Item {
					id: row
					required property var modelData
					required property int index
					readonly property var r: modelData
					readonly property var au: r.node && r.node.audio ? r.node.audio : null
					readonly property bool selected: win.sel === index
					readonly property var props: r.node && r.node.properties ? r.node.properties : ({})
					readonly property string media: r.kind === "vol" && !r.master ? (props["media.name"] || "") : ""
					readonly property real vol: au ? au.volume : 0
					width: ListView.view.width
					height: r.kind === "header" ? 30 : r.kind === "empty" ? Theme.rowHeight : r.kind === "dev" ? Theme.rowHeight : Theme.rowHeight + 8

					// Header
					Header {
						visible: row.r.kind === "header"
						anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: Theme.spacing; rightMargin: Theme.spacing }
						title: row.r.title || ""
					}

					Txt {
						visible: row.r.kind === "empty"
						anchors.fill: parent
						anchors.leftMargin: Theme.pad
						text: row.r.text || ""
						muted: true
					}

					// Selectable rows
					Rectangle {
						visible: row.r.kind === "vol" || row.r.kind === "dev"
						anchors.fill: parent
						radius: Theme.roundingSmall
						color: row.selected ? Theme.surfaceTop : rowMouse.containsMouse ? Theme.surfaceHi : "transparent"
						border.width: row.selected ? Math.max(Theme.border, 1) : 0
						border.color: Theme.primary
						Behavior on color { ColorAnimation { duration: Theme.animFast } }
					}

					MouseArea {
						id: rowMouse
						visible: row.r.kind === "vol" || row.r.kind === "dev"
						anchors.fill: parent
						hoverEnabled: true
						onPositionChanged: function (m) {
							var g = rowMouse.mapToItem(null, m.x, m.y);
							if (Math.abs(g.x - win.lastHover.x) + Math.abs(g.y - win.lastHover.y) < 3) return;
							win.lastHover = Qt.point(g.x, g.y);
							win.sel = row.index;
						}
						onClicked: { win.sel = row.index; if (row.r.kind === "dev") win.activate(row.r); }
						onWheel: function (w) {
							if (row.r.kind !== "vol") { w.accepted = false; return; }
							win.sel = row.index;
							win.setVol(row.r, row.vol + (w.angleDelta.y > 0 ? 0.05 : -0.05));
						}
					}

					// Volume row
					RowLayout {
						visible: row.r.kind === "vol"
						anchors.fill: parent
						anchors.leftMargin: Theme.pad
						anchors.rightMargin: Theme.spacing
						spacing: Theme.spacing

						Item {
							Layout.preferredWidth: Theme.iconSize + 8
							Layout.preferredHeight: Theme.iconSize + 2
							AppIcon {
								visible: !row.r.master && row.r.kind === "vol"
								app: row.r.node && !row.r.master ? Audio.streamIcon(row.r.node) : ""
								size: Theme.iconSize + 2
							}
							Icon {
								visible: !!row.r.master
								anchors.centerIn: parent
								glyph: row.r.mic ? (row.au && row.au.muted ? Icons.micOff : Icons.mic) : (row.au && row.au.muted ? Icons.volumeOff : Icons.volumeHigh)
								color: row.selected ? Theme.primary : Theme.fgDim
							}
						}

						ColumnLayout {
							Layout.preferredWidth: 190
							spacing: 0
							Txt {
								Layout.fillWidth: true
								text: !row.r.node ? "" : row.r.master ? Audio.label(row.r.node) : Audio.streamName(row.r.node)
								bold: !!row.r.master
							}
							Txt {
								Layout.fillWidth: true
								visible: row.media !== ""
								text: row.media
								size: Theme.fontSmall
								muted: true
							}
						}

						ColumnLayout {
							Layout.fillWidth: true
							spacing: 2
							Slider {
								Layout.fillWidth: true
								value: row.vol
								max: win.maxVol
								enabled: !!row.au && !row.au.muted
								onMoved: v => { win.sel = row.index; win.setVol(row.r, v); }
							}
							Meter {
								Layout.fillWidth: true
								Layout.preferredHeight: 3
								value: Math.sqrt(peak.peak)
								warnAt: 0.85
								critAt: 0.97
								opacity: row.au && row.au.muted ? 0.3 : 1
							}
						}

						Txt {
							Layout.preferredWidth: 44
							text: Math.round(row.vol * 100) + "%"
							mono: true
							dim: true
							horizontalAlignment: Text.AlignRight
						}

						Btn {
							icon: row.au && row.au.muted ? Icons.volumeOff : Icons.volumeHigh
							flat: true
							onClicked: win.toggleMute(row.r)
						}
					}

					// Level meter source: only exists while the overlay is open.
					PwNodePeakMonitor {
						id: peak
						node: row.r.kind === "vol" ? row.r.node : null
						enabled: row.r.kind === "vol"
					}

					// Device row
					RowLayout {
						visible: row.r.kind === "dev"
						anchors.fill: parent
						anchors.leftMargin: Theme.pad
						anchors.rightMargin: Theme.pad
						spacing: Theme.spacing
						Icon {
							glyph: row.r.mic ? Icons.mic : Icons.volumeHigh
							color: win.isDefault(row.r) ? Theme.primary : Theme.fgMuted
						}
						Txt {
							Layout.fillWidth: true
							text: row.r.node ? Audio.label(row.r.node) : ""
							color: win.isDefault(row.r) ? Theme.primary : Theme.fg
						}
						Icon {
							visible: win.isDefault(row.r)
							glyph: Icons.check
							color: Theme.primary
						}
					}
				}
			}

			Txt {
				id: hint
				anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.pad }
				height: implicitHeight
				text: "Up/Down select   Left/Right volume   M mute   0-9 set   Tab section   Enter default   Esc close"
				size: Theme.fontSmall
				muted: true
				horizontalAlignment: Text.AlignHCenter
			}
		}
	}
}
