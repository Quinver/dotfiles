import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets
import "../config/Palette.js" as Palette

// Theme Studio overlay (Ui.overlay === "themes" | "settings").
//   browse: carousel of themes with wallpaper previews; apply, or open the editor.
//   edit:   option editor for the global scope or for one theme's overrides.
// While browsing, the focused theme and wallpaper are previewed live across the shell
// (Settings.previewTheme / Wallpapers.previewPath, in-memory only); only apply persists.
// Opened with `qs ipc call shell overlay themes` / `... overlay settings`.
Scope {
	id: studio

	// Live preview state lives outside the window so it is always reverted,
	// however the overlay goes away (Esc, click outside, IPC, another overlay).
	function revert() {
		Settings.previewTheme = "";
		Wallpapers.previewPath = "";
	}

	Connections {
		target: Ui
		function onOverlayChanged() {
			if (Ui.overlay !== "themes" && Ui.overlay !== "settings") studio.revert();
		}
	}

	LazyLoader {
		active: Ui.overlay === "themes" || Ui.overlay === "settings"

		PanelWindow {
			id: win
			screen: Ui.overlayScreen
			WlrLayershell.layer: WlrLayer.Overlay
			WlrLayershell.namespace: "qs-themes"
			WlrLayershell.keyboardFocus: Ui.testMode ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
			exclusionMode: ExclusionMode.Ignore
			anchors { top: true; bottom: true; left: true; right: true }
			color: "transparent"

			property string view: "browse"          // browse | edit
			property string editScope: "global"     // "global" or a theme name
			property string editTheme: ""           // theme the editor can swap to with Tab
			property bool cameFromBrowser: false

			// Static option schema: values are read through bindings, never rebuilt.
			// values: "$themes" expands to the theme names at use time.
			readonly property var schema: [
				{ section: "Appearance" },
				{ key: "mode", label: "Mode", type: "enum", values: ["dark", "light"] },
				{ key: "chroma", label: "Chroma", type: "real", min: 0, max: 1.5, step: 0.05 },
				{ key: "rounding", label: "Rounding", type: "int", min: 0, max: 20, step: 1 },
				{ key: "border", label: "Border", type: "int", min: 0, max: 6, step: 1 },
				{ key: "hyprBorder", label: "Window border", type: "int", min: 0, max: 6, step: 1 },
				{ key: "gap", label: "Gap", type: "int", min: 0, max: 32, step: 1 },
				{ key: "pad", label: "Padding", type: "int", min: 4, max: 24, step: 1 },
				{ key: "barHeight", label: "Bar height", type: "int", min: 24, max: 64, step: 2 },
				{ key: "fontSize", label: "Font size", type: "int", min: 9, max: 18, step: 1 },
				{ key: "barOpacity", label: "Bar opacity", type: "real", min: 0.3, max: 1, step: 0.05 },
				{ key: "panelOpacity", label: "Panel opacity", type: "real", min: 0.3, max: 1, step: 0.05 },
				{ key: "animSpeed", label: "Animation speed", type: "real", min: 0, max: 3, step: 0.25 },
				{ section: "Wallpaper" },
				{ key: "rotate", label: "Rotate wallpapers", type: "bool" },
				{ key: "rotateInterval", label: "Rotate every", type: "int", min: 60, max: 7200, step: 60 },
				{ key: "rotateOrder", label: "Rotate order", type: "enum", values: ["sequential", "random"] },
				{ section: "Integration" },
				{ key: "applyHyprland", label: "Colour Hyprland", type: "bool" },
				{ key: "applyAlacritty", label: "Colour Alacritty", type: "bool" },
				{ key: "gtkTint", label: "Tint GTK apps", type: "bool" },
				{ section: "Desktop" },
				{ key: "desktopClock", label: "Desktop clock", type: "bool" },
				{ key: "desktopMedia", label: "Desktop now playing", type: "bool" },
				{ key: "desktopSystem", label: "Desktop system stats", type: "bool" },
				{ key: "desktopPosition", label: "Widget position", type: "enum", values: ["bottom-left", "bottom-right", "top-left", "top-right", "center-left"] },
				{ key: "desktopBackdrop", label: "Widget backdrop", type: "bool" },
				{ section: "Behaviour", globalOnly: true },
				{ key: "workspaces", label: "Workspaces", type: "int", min: 1, max: 10, step: 1, globalOnly: true },
				{ key: "notifyTimeout", label: "Notification timeout (s)", type: "int", min: 2, max: 30, step: 1, globalOnly: true },
				{ key: "startupTheme", label: "Startup theme", type: "enum", values: ["last", "$themes"], globalOnly: true },
				{ key: "safeTheme", label: "Safe theme", type: "enum", values: ["$themes"], globalOnly: true }
			]
			readonly property bool themeScope: editScope !== "global"
			readonly property var rows: schema.filter(r => !(themeScope && r.globalOnly))
			property int sel: 1

			// Wallpaper lists per theme and the previewed index per theme.
			property var lists: ({})
			property var wpIdx: ({})
			property bool listsLoaded: false

			function enumValues(r) {
				var out = [];
				for (var i = 0; i < r.values.length; i++) {
					if (r.values[i] === "$themes") out = out.concat(Settings.themeNames);
					else out.push(r.values[i]);
				}
				return out;
			}

			function effective(key) {
				if (themeScope) {
					var o = Settings.themeOptionRaw(editScope, key);
					if (o !== undefined) return o;
				}
				return Settings.globalValue(key);
			}

			function isOverride(key) { return themeScope && Settings.themeOptionRaw(editScope, key) !== undefined; }

			function setValue(key, v) {
				if (themeScope) Settings.setThemeOption(key, v, editScope);
				else Settings.setOption(key, v);
			}

			function resetRow(r) {
				if (themeScope && r && r.key && isOverride(r.key)) Settings.setThemeOption(r.key, null, editScope);
			}

			function adjust(r, dir) {
				if (!r || !r.key) return;
				var v = effective(r.key);
				if (r.type === "bool") {
					setValue(r.key, !v);
				} else if (r.type === "enum") {
					var vals = enumValues(r);
					if (!vals.length) return;
					var i = vals.indexOf(v);
					setValue(r.key, vals[(i + dir + vals.length * 2) % vals.length]);
				} else {
					var n = Math.max(r.min, Math.min(r.max, Math.round((Number(v) + dir * r.step) * 1000) / 1000));
					if (n !== v) setValue(r.key, n);
				}
			}

			function format(r, v) {
				if (r.type === "bool") return v ? "on" : "off";
				if (r.key === "rotateInterval") return Math.round(v / 6) / 10 + " min";
				if (r.type === "real") return (Math.round(Number(v) * 100) / 100).toString();
				return String(v);
			}

			function moveSel(d) {
				var i = sel;
				for (var n = 0; n < rows.length; n++) {
					i = (i + d + rows.length) % rows.length;
					if (!rows[i].section) break;
				}
				sel = i;
				if (i > 0 && rows[i - 1].section) rowList.positionViewAtIndex(i - 1, ListView.Contain);
				rowList.positionViewAtIndex(i, ListView.Contain);
			}

			function firstRow() {
				for (var i = 0; i < rows.length; i++) if (!rows[i].section) return i;
				return 0;
			}

			// ---- wallpapers per theme ----
			function wallpapersOf(name) { return lists[name] || []; }

			function previewPath(name) {
				var l = wallpapersOf(name);
				return l.length ? l[Math.min(wpIdx[name] || 0, l.length - 1)] : "";
			}

			function cycleWallpaper(name, d) {
				var l = wallpapersOf(name);
				if (!l.length) return;
				var m = Object.assign({}, wpIdx);
				m[name] = ((m[name] || 0) + d + l.length) % l.length;
				wpIdx = m;
			}

			function applyTheme(name) {
				var path = previewPath(name);
				previewTimer.stop();
				if (path !== "" && name !== Settings.savedThemeName) {
					var m = Object.assign({}, Settings.state.wallpapers || {});
					m[name] = path;
					Settings.setState("wallpapers", m);
				}
				Settings.setTheme(name);
				// Drop the preview, then persist the wallpaper (Wallpapers.set remembers it).
				studio.revert();
				if (path !== "") {
					if (Wallpapers.files.indexOf(path) >= 0) Wallpapers.set(path);
					else Wallpapers.refresh();
				}
				Ui.close();
			}

			// Live preview of the focused card, debounced.
			function updatePreview() {
				if (view !== "browse") return;
				var n = focusedName();
				Settings.previewTheme = n === Settings.savedThemeName ? "" : n;
				Wallpapers.previewPath = previewPath(n);
			}

			property point lastHover: Qt.point(-100, -100)

			Timer { id: previewTimer; interval: 150; onTriggered: win.updatePreview() }
			onWpIdxChanged: if (view === "browse") previewTimer.restart()

			function openFor(name) {
				if (name === "settings") {
					studio.revert();
					cameFromBrowser = false;
					editTheme = "";
					editScope = "global";
					sel = firstRow();
					view = "edit";
				} else {
					view = "browse";
					cameFromBrowser = false;
					var i = Settings.themeNames.indexOf(Settings.themeName);
					carousel.currentIndex = Math.max(0, i);
					carousel.positionViewAtIndex(carousel.currentIndex, ListView.Center);
					previewTimer.stop();   // preview starts on focus change only
				}
			}

			function openEdit(scope, themeName) {
				cameFromBrowser = true;
				editTheme = themeName;
				editScope = scope;
				sel = firstRow();
				view = "edit";
				rowList.positionViewAtBeginning();
			}

			function focusedName() { return Settings.themeNames[carousel.currentIndex] || ""; }

			function back() {
				if (view === "edit" && cameFromBrowser) {
					view = "browse";
					var i = Settings.themeNames.indexOf(editTheme);
					if (i >= 0) carousel.currentIndex = i;
				} else {
					Ui.close();
				}
			}

			function step(d) {
				var n = Settings.themeNames.length;
				if (n) carousel.currentIndex = (carousel.currentIndex + d + n) % n;
			}

			Component.onCompleted: { openFor(Ui.overlay); keys.forceActiveFocus(); }
			onVisibleChanged: if (visible) keys.forceActiveFocus()
			onWindowConnected: keys.forceActiveFocus()

			Connections {
				target: Ui
				function onOverlayChanged() { if (Ui.overlay === "themes" || Ui.overlay === "settings") win.openFor(Ui.overlay); }
			}

			// One process lists every theme's wallpapers: "theme<TAB>path" lines.
			Process {
				id: lister
				running: true
				command: {
					var script = "for t in \"$@\"; do d=${t#*=}; n=${t%%=*}; find -L \"$d\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort | while IFS= read -r f; do printf '%s\\t%s\\n' \"$n\" \"$f\"; done; done";
					var args = ["sh", "-c", script, "sh"];
					for (var i = 0; i < Settings.themeNames.length; i++) {
						var n = Settings.themeNames[i];
						args.push(n + "=" + Settings.expand(Settings.themes[n].wallpapers || "/nonexistent"));
					}
					return args;
				}
				stdout: StdioCollector {
					onStreamFinished: {
						var out = {};
						text.split("\n").forEach(function (line) {
							var t = line.indexOf("\t");
							if (t < 0) return;
							var n = line.substring(0, t);
							if (!out[n]) out[n] = [];
							out[n].push(line.substring(t + 1));
						});
						var idx = {};
						var saved = Settings.state.wallpapers || {};
						for (var k in out) {
							var i = out[k].indexOf(saved[k]);
							idx[k] = i < 0 ? 0 : i;
						}
						win.lists = out;
						win.wpIdx = idx;
						win.listsLoaded = true;
					}
				}
			}

			MouseArea {
				anchors.fill: parent
				onClicked: Ui.close()
			}

			Item {
				id: keys
				anchors.fill: parent
				focus: true
				Keys.onPressed: function (ev) {
					var k = ev.key;
					var shift = (ev.modifiers & Qt.ShiftModifier) !== 0;
					var handled = true;
					if (win.view === "browse") {
						if (k === Qt.Key_Escape || k === Qt.Key_Q) Ui.close();
						else if (k === Qt.Key_Right || k === Qt.Key_D || k === Qt.Key_L || (k === Qt.Key_Tab && !shift)) win.step(1);
						else if (k === Qt.Key_Left || k === Qt.Key_A || k === Qt.Key_H || k === Qt.Key_Backtab || (k === Qt.Key_Tab && shift)) win.step(-1);
						else if (k === Qt.Key_Down || k === Qt.Key_S || k === Qt.Key_J) win.cycleWallpaper(win.focusedName(), 1);
						else if (k === Qt.Key_Up || k === Qt.Key_W || k === Qt.Key_K) win.cycleWallpaper(win.focusedName(), -1);
						else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) win.applyTheme(win.focusedName());
						else if (k === Qt.Key_E) win.openEdit(win.focusedName(), win.focusedName());
						else if (k === Qt.Key_G || k === Qt.Key_Comma) win.openEdit("global", win.focusedName());
						else handled = false;
					} else {
						var row = win.rows[win.sel];
						if (k === Qt.Key_Escape || k === Qt.Key_Q) win.back();
						else if (k === Qt.Key_Down || k === Qt.Key_S || k === Qt.Key_J) win.moveSel(1);
						else if (k === Qt.Key_Up || k === Qt.Key_W || k === Qt.Key_K) win.moveSel(-1);
						else if (k === Qt.Key_Right || k === Qt.Key_D || k === Qt.Key_L) win.adjust(row, 1);
						else if (k === Qt.Key_Left || k === Qt.Key_A || k === Qt.Key_H) win.adjust(row, -1);
						else if ((k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) && row && row.type === "bool") win.adjust(row, 1);
						else if (k === Qt.Key_X || k === Qt.Key_Backspace || k === Qt.Key_Delete) win.resetRow(row);
						else if (k === Qt.Key_Tab && win.cameFromBrowser && win.editTheme !== "") win.editScope = win.themeScope ? "global" : win.editTheme;
						else handled = false;
					}
					ev.accepted = handled;
				}
			}

			// ===================== BROWSE =====================
			Item {
				id: browse
				anchors.fill: parent
				visible: opacity > 0
				opacity: win.view === "browse" ? 1 : 0
				Behavior on opacity { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

				readonly property real cardW: Math.min(420, win.width * 0.24)
				readonly property real imageH: cardW * 0.6
				readonly property real cardH: imageH + 106

				WheelHandler {
					property real acc: 0
					onWheel: function (ev) {
						acc += ev.angleDelta.y;
						if (acc <= -120) { win.step(1); acc = 0; }
						else if (acc >= 120) { win.step(-1); acc = 0; }
					}
				}

				Rectangle {
					anchors.left: parent.left
					anchors.right: parent.right
					y: carousel.y - Theme.pad * 4
					height: carousel.height + Theme.pad * 11
					gradient: Gradient {
						GradientStop { position: 0; color: Theme.alpha(Theme.bg, 0) }
						GradientStop { position: 0.3; color: Theme.alpha(Theme.bg, 0.7) }
						GradientStop { position: 0.7; color: Theme.alpha(Theme.bg, 0.7) }
						GradientStop { position: 1; color: Theme.alpha(Theme.bg, 0) }
					}
				}

				ListView {
					id: carousel
					anchors.left: parent.left
					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					anchors.verticalCenterOffset: -Theme.pad * 2
					height: browse.cardH + 8
					orientation: ListView.Horizontal
					interactive: false
					spacing: Theme.pad * 2
					model: Settings.themeNames
					highlightRangeMode: ListView.StrictlyEnforceRange
					preferredHighlightBegin: (width - browse.cardW) / 2
					preferredHighlightEnd: (width + browse.cardW) / 2
					highlightMoveDuration: Theme.animSlow
					highlightMoveVelocity: -1
				onCurrentIndexChanged: if (win.view === "browse") previewTimer.restart()

					delegate: Item {
						id: slot
						required property string modelData
						required property int index
						readonly property bool focused: ListView.isCurrentItem
						readonly property var themeCfg: Settings.themes[modelData] || ({})
						readonly property var colorCfg: themeCfg.colors || ({})
						readonly property string source: colorCfg.source || "wallpaper"
						readonly property var files: win.wallpapersOf(modelData)
						readonly property string path: win.previewPath(modelData)
						readonly property string modeName: Settings.themeOptionRaw(modelData, "mode") ?? Settings.globalValue("mode")
						// The focused card is the live theme, so its swatches are the real tokens.
					readonly property bool live: focused && modelData === Settings.themeName
					property string extracted: ""
						readonly property string seed: source === "wallpaper" ? extracted : source === "seed" ? (colorCfg.seed || "") : "#808080"
						readonly property var pal: seed === "" ? null : Palette.generate(seed, {
							mode: modeName,
							mono: source === "mono",
							chroma: Settings.themeOptionRaw(modelData, "chroma") ?? Settings.globalValue("chroma"),
							overrides: themeCfg.palette
						})

						width: browse.cardW
						height: carousel.height

						ColorQuantizer {
							source: slot.source === "wallpaper" && slot.path !== "" ? Wallpapers.url(slot.path) : ""
							depth: 4
							rescaleSize: 64
							onColorsChanged: if (colors.length) slot.extracted = Palette.pickSeed(colors.map(c => c.toString()))
						}

						Item {
							id: card
							width: parent.width
							height: browse.cardH
							anchors.verticalCenter: parent.verticalCenter
							scale: slot.focused ? 1 : 0.82
							Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

							Rectangle {
								anchors.fill: parent
								radius: Theme.rounding
								color: Theme.surface
								border.width: slot.focused ? Math.max(Theme.border, 2) : Theme.border
								border.color: slot.focused ? Theme.primary : Theme.outlineDim
								Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
							}

							Rectangle {
								id: imageBox
								x: Theme.border
								y: Theme.border
								width: parent.width - Theme.border * 2
								height: browse.imageH
								color: Theme.surfaceHi
								clip: true

								Image {
									anchors.fill: parent
									visible: slot.path !== ""
									source: slot.path !== "" ? Wallpapers.url(slot.path) : ""
									sourceSize.width: 640
									asynchronous: true
									fillMode: Image.PreserveAspectCrop
								}

								Txt {
									anchors.centerIn: parent
									width: parent.width - Theme.pad * 2
									horizontalAlignment: Text.AlignHCenter
									visible: slot.path === ""
									muted: true
									text: win.listsLoaded ? "No wallpapers in " + (slot.themeCfg.wallpapers || "this theme") : "Loading wallpapers"
								}
							}

							Column {
								x: Theme.pad
								y: browse.imageH + Theme.pad
								width: parent.width - Theme.pad * 2
								spacing: 4

								Txt {
									width: parent.width
									size: Theme.fontLarge
									bold: true
									text: Settings.themeLabel(slot.modelData)
								}
								Txt {
									width: parent.width
									size: Theme.fontSmall
									dim: true
									text: slot.source + " · " + slot.modeName + (slot.modelData === Settings.savedThemeName ? " · active" : "")
									color: slot.modelData === Settings.savedThemeName ? Theme.primary : Theme.fgDim
								}
								Row {
									spacing: 4
									height: 22
									visible: slot.pal !== null || slot.live
									Repeater {
										model: (slot.pal || slot.live) ? ["bg", "surfaceTop", "primary", "secondary", "tertiary", "fg"] : []
										delegate: Rectangle {
											required property string modelData
											width: 22
											height: 22
											radius: Theme.roundingSmall
											color: slot.live ? Theme[modelData] : slot.pal[modelData]
											border.width: 1
											border.color: Theme.outlineDim
										}
									}
								}
							}

							// Non-focused cards are dimmed; hovering lifts the dim.
							Rectangle {
								anchors.fill: parent
								radius: Theme.rounding
								color: Theme.bg
								opacity: slot.focused ? 0 : (cardMouse.containsMouse ? 0.25 : 0.55)
								Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
							}

							MouseArea {
								id: cardMouse
								anchors.fill: parent
								hoverEnabled: true
								acceptedButtons: Qt.LeftButton | Qt.RightButton
								cursorShape: Qt.PointingHandCursor
								// Hover focuses only when the pointer really moved (not when the list scrolls under it).
								onPositionChanged: function (m) {
									var g = cardMouse.mapToItem(null, m.x, m.y);
									if (Math.abs(g.x - win.lastHover.x) + Math.abs(g.y - win.lastHover.y) < 3) return;
									win.lastHover = Qt.point(g.x, g.y);
									if (!slot.focused && win.view === "browse") carousel.currentIndex = slot.index;
								}
								onClicked: function (m) {
									if (m.button === Qt.RightButton) {
										carousel.currentIndex = slot.index;
										win.openEdit(slot.modelData, slot.modelData);
									} else if (slot.focused) {
										win.applyTheme(slot.modelData);
									} else {
										carousel.currentIndex = slot.index;
									}
								}
							}
						}
					}
				}

				Txt {
					anchors.horizontalCenter: parent.horizontalCenter
					anchors.top: carousel.bottom
					anchors.topMargin: Theme.pad
					muted: true
					text: {
						var n = win.focusedName();
						var l = win.wallpapersOf(n);
						return l.length ? "wallpaper " + (Math.min(win.wpIdx[n] || 0, l.length - 1) + 1) + "/" + l.length : "no wallpapers";
					}
				}

				Rectangle {
					anchors.horizontalCenter: parent.horizontalCenter
					anchors.bottom: parent.bottom
					anchors.bottomMargin: Theme.pad * 2
					width: browseHint.implicitWidth + Theme.pad * 2
					height: browseHint.implicitHeight + Theme.pad
					radius: Theme.roundingSmall
					color: Theme.alpha(Theme.surface, 0.85)
				}

				Txt {
					id: browseHint
					anchors.horizontalCenter: parent.horizontalCenter
					anchors.verticalCenter: parent.bottom
					anchors.verticalCenterOffset: -Theme.pad * 2 - (implicitHeight + Theme.pad) / 2
					size: Theme.fontSmall
					muted: true
					text: "←→ / A D / H L themes · ↑↓ / W S / K J wallpaper · ⏎ apply · E edit theme · G global · Esc close"
				}
			}

			// ===================== EDIT =====================
			Item {
				id: edit
				anchors.fill: parent
				visible: opacity > 0
				opacity: win.view === "edit" ? 1 : 0
				Behavior on opacity { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

				MouseArea { anchors.fill: parent; onClicked: Ui.close() }

				Box {
					id: panel
					width: Math.min(720, win.width * 0.6)
					height: Math.min(win.height * 0.8, 760)
					x: (parent.width - width) / 2
					y: (parent.height - height) / 2 + (win.view === "edit" ? 0 : Theme.pad * 2)
					Behavior on y { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

					MouseArea { anchors.fill: parent }

					Column {
						id: head
						x: Theme.pad
						y: Theme.pad
						width: parent.width - Theme.pad * 2
						spacing: 2
						Txt {
							width: parent.width
							size: Theme.fontLarge
							bold: true
							text: win.themeScope ? Settings.themeLabel(win.editScope) + " — theme overrides" : "Global settings"
						}
						Txt {
							width: parent.width
							size: Theme.fontSmall
							muted: true
							text: win.themeScope ? "Overrides apply to this theme only; everything else follows the global setting." : "Defaults used by every theme that does not override them."
						}
					}

					Sep {
						id: topSep
						anchors.top: head.bottom
						anchors.topMargin: Theme.pad
						anchors.left: parent.left
						anchors.right: parent.right
					}

					ListView {
						id: rowList
						anchors.top: topSep.bottom
						anchors.bottom: botSep.top
						anchors.left: parent.left
						anchors.right: parent.right
						clip: true
						boundsBehavior: Flickable.StopAtBounds
						model: win.rows

						delegate: Item {
							id: rowItem
							required property var modelData
							required property int index
							readonly property bool isSection: modelData.section !== undefined
							readonly property bool selected: !isSection && win.sel === index
							readonly property bool override: !isSection && win.isOverride(modelData.key)
							readonly property var val: isSection ? null : win.effective(modelData.key)
							width: ListView.view.width
							height: isSection ? 34 : 38

							Txt {
								visible: rowItem.isSection
								x: Theme.pad
								anchors.bottom: parent.bottom
								anchors.bottomMargin: 4
								text: rowItem.modelData.section ? rowItem.modelData.section.toUpperCase() : ""
								size: Theme.fontSmall
								bold: true
								muted: true
								font.letterSpacing: 1.2
							}

							Rectangle {
								visible: !rowItem.isSection
								anchors.fill: parent
								color: rowItem.selected ? Theme.surfaceHi : (rowMouse.containsMouse ? Theme.alpha(Theme.surfaceHi, 0.5) : "transparent")
								Behavior on color { ColorAnimation { duration: Theme.animFast } }
								Rectangle {
									width: 3
									height: parent.height
									color: Theme.primary
									opacity: rowItem.selected ? 1 : 0
									Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
								}
							}

							MouseArea {
								id: rowMouse
								visible: !rowItem.isSection
								anchors.fill: parent
								hoverEnabled: true
								onClicked: win.sel = rowItem.index
							}

							Txt {
								visible: !rowItem.isSection
								x: Theme.pad * 1.5
								anchors.verticalCenter: parent.verticalCenter
								width: Math.max(0, tag.x - x - Theme.pad)
								text: rowItem.isSection ? "" : rowItem.modelData.label
							}

							Txt {
								id: tag
								visible: win.themeScope && !rowItem.isSection
								anchors.verticalCenter: parent.verticalCenter
								x: controls.x - width - Theme.pad * 2
								size: Theme.fontSmall
								color: rowItem.override ? Theme.primary : Theme.fgMuted
								text: rowItem.override ? "override" : "inherited"
							}

							Row {
								id: controls
								visible: !rowItem.isSection
								anchors.verticalCenter: parent.verticalCenter
								anchors.right: parent.right
								anchors.rightMargin: Theme.pad
								spacing: 4

								Btn {
									visible: win.themeScope
									enabled: rowItem.override
									flat: true
									icon: Icons.close
									iconSize: Theme.fontSize
									onClicked: win.resetRow(rowItem.modelData)
								}

								Toggle {
									visible: !rowItem.isSection && rowItem.modelData.type === "bool"
									anchors.verticalCenter: parent.verticalCenter
									checked: rowItem.val === true
									onToggled: { win.sel = rowItem.index; win.adjust(rowItem.modelData, 1); }
								}

								Row {
									visible: !rowItem.isSection && rowItem.modelData.type !== "bool"
									spacing: 0
									Btn {
										flat: true
										icon: Icons.chevronLeft
										iconSize: Theme.fontSize
										onClicked: { win.sel = rowItem.index; win.adjust(rowItem.modelData, -1); }
									}
									Txt {
										width: 110
										height: Theme.rowHeight
										horizontalAlignment: Text.AlignHCenter
										mono: true
										color: rowItem.override || !win.themeScope ? Theme.fg : Theme.fgMuted
										text: rowItem.isSection || rowItem.val === null ? "" : win.format(rowItem.modelData, rowItem.val)
									}
									Btn {
										flat: true
										icon: Icons.chevronRight
										iconSize: Theme.fontSize
										onClicked: { win.sel = rowItem.index; win.adjust(rowItem.modelData, 1); }
									}
								}
							}
						}
					}

					Sep {
						id: botSep
						anchors.bottom: hint.top
						anchors.bottomMargin: Theme.pad
						anchors.left: parent.left
						anchors.right: parent.right
					}

					Txt {
						id: hint
						anchors.bottom: parent.bottom
						anchors.bottomMargin: Theme.pad
						anchors.left: parent.left
						anchors.right: parent.right
						anchors.leftMargin: Theme.pad
						anchors.rightMargin: Theme.pad
						horizontalAlignment: Text.AlignHCenter
						size: Theme.fontSmall
						muted: true
						text: "↑↓ / W S / K J select · ←→ / A D / H L change · ⏎ toggle" + (win.themeScope ? " · X reset" : "")
							+ (win.cameFromBrowser ? " · Tab scope · Esc back" : " · Esc close")
					}
				}
			}
		}
	}
}
