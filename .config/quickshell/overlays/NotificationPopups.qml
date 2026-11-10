import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Always-on notification popup stack (top right, below the bar). One window on
// the screen that was focused when the first popup appeared; it never takes
// focus and is click-through outside the cards. Driven by Notifs.popups.
// Layer Top, so a fullscreen game covers it.
Scope {
	id: root

	property var screenChoice: null
	property var wrappers: ({})     // key -> wrapper; kept while cards animate out

	// ListView needs a real model for add/remove transitions, so mirror
	// Notifs.popups into a ListModel of keys (newest first).
	ListModel { id: model }

	function sync() {
		var want = Notifs.popups;
		var keys = want.map(w => w.key);
		for (var i = model.count - 1; i >= 0; i--)
			if (keys.indexOf(model.get(i).key) < 0) model.remove(i);
		if (want.length > 0 && model.count === 0) {
			root.wrappers = ({});
			root.screenChoice = Ui.focusedScreen();
		}
		for (var j = 0; j < want.length; j++) {
			if (j < model.count && model.get(j).key === want[j].key) continue;
			root.wrappers[want[j].key] = want[j];
			model.insert(j, { key: want[j].key });
		}
	}

	Connections {
		target: Notifs
		function onPopupsChanged() { root.sync(); }
	}

	PanelWindow {
		id: win
		visible: model.count > 0
		screen: root.screenChoice || Quickshell.screens[0]
		color: "transparent"
		WlrLayershell.layer: WlrLayer.Top
		WlrLayershell.namespace: "qs-notifications"
		WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
		anchors { top: true; right: true }
		margins { top: Theme.gap; right: Theme.gap }
		implicitWidth: 380
		implicitHeight: Math.max(1, stack.contentHeight)
		mask: Region { item: stack }

		ListView {
			id: stack
			anchors.fill: parent
			interactive: false
			spacing: Theme.spacing
			model: model

			add: Transition {
				ParallelAnimation {
					NumberAnimation { property: "x"; from: 380; to: 0; duration: Theme.anim; easing.type: Easing.OutCubic }
					NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.anim }
				}
			}
			remove: Transition {
				ParallelAnimation {
					NumberAnimation { property: "x"; to: 380; duration: Theme.anim; easing.type: Easing.InCubic }
					NumberAnimation { property: "opacity"; to: 0; duration: Theme.anim }
				}
			}
			displaced: Transition {
				NumberAnimation { property: "y"; duration: Theme.anim; easing.type: Easing.OutCubic }
			}

			delegate: Item {
				id: card
				required property int key
				readonly property var w: root.wrappers[key]

				// Snapshots that freeze when the notification is closed, so the
				// card can animate out without touching a destroyed object.
				property bool gone: false
				property string summary: ""
				property string body: ""
				property string appName: ""
				property int urgency: 1
				property string iconSource: ""
				property var buttons: []
				property var defAction: null
				Binding { target: card; property: "summary"; value: card.w.n.summary; when: !card.gone && !!card.w && !!card.w.n }
				Binding { target: card; property: "body"; value: card.w.n.body; when: !card.gone && !!card.w && !!card.w.n }
				Binding { target: card; property: "appName"; value: card.w.n.appName; when: !card.gone && !!card.w && !!card.w.n }
				Binding { target: card; property: "urgency"; value: card.w.n.urgency; when: !card.gone && !!card.w && !!card.w.n }
				Binding { target: card; property: "iconSource"; value: Notifs.icon(card.w); when: !card.gone && !!card.w && !!card.w.n }
				Binding { target: card; property: "buttons"; value: Notifs.buttonActions(card.w); when: !card.gone && !!card.w && !!card.w.n }
				Binding { target: card; property: "defAction"; value: Notifs.defaultAction(card.w); when: !card.gone && !!card.w && !!card.w.n }
				Connections {
					target: card.w.n
					ignoreUnknownSignals: true
					function onClosed() { card.gone = true; }
				}

				readonly property color accent: urgency === 2 ? Theme.error : urgency === 0 ? Theme.fgMuted : Theme.primary

				width: 380
				height: frame.height

				Box {
					id: frame
					width: parent.width
					height: content.implicitHeight + Theme.pad * 2
					level: 1
					border.color: Theme.outline

					Rectangle {
						width: 3
						height: parent.height
						color: card.accent
					}

					MouseArea {
						anchors.fill: parent
						acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
						onClicked: function (m) {
							if (m.button === Qt.RightButton) Notifs.dismiss(card.w);
							else if (m.button === Qt.MiddleButton) Notifs.hidePopup(card.w);
							else if (card.defAction) Notifs.invoke(card.w, card.defAction);
							else Notifs.dismiss(card.w);
						}
					}

					HoverHandler {
						id: hover
						onHoveredChanged: Notifs.setPaused(card.w, hovered)
					}

					Row {
						id: content
						x: Theme.pad + 3
						y: Theme.pad
						width: parent.width - Theme.pad * 2 - 3
						spacing: Theme.pad

						Box {
							id: iconBox
							width: 40
							height: 40
							small: true
							level: 2
							outlined: false
							Image {
								id: img
								anchors.fill: parent
								source: card.iconSource
								sourceSize: Qt.size(80, 80)
								fillMode: Image.PreserveAspectFit
								asynchronous: true
								visible: status === Image.Ready
							}
							Icon {
								anchors.centerIn: parent
								visible: !img.visible
								glyph: Icons.bell
								color: Theme.fgMuted
							}
						}

						Column {
							width: parent.width - iconBox.width - parent.spacing
							spacing: 3

							Item {
								width: parent.width
								height: 20
								Txt {
									id: appLabel
									anchors.left: parent.left
									anchors.verticalCenter: parent.verticalCenter
									width: Math.min(implicitWidth, parent.width - timeLabel.width - 40)
									text: card.appName
									size: Theme.fontSmall
									muted: true
								}
								Txt {
									id: timeLabel
									anchors.left: appLabel.right
									anchors.leftMargin: Theme.spacing
									anchors.verticalCenter: parent.verticalCenter
									text: card.w ? Notifs.timeAgo(card.w.time) : ""
									size: Theme.fontSmall
									muted: true
								}
								Btn {
									anchors.right: parent.right
									anchors.verticalCenter: parent.verticalCenter
									width: 22
									height: 22
									flat: true
									icon: Icons.close
									iconSize: Theme.fontSmall
									opacity: hover.hovered ? 1 : 0
									Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
									onClicked: Notifs.dismiss(card.w)
								}
							}

							Txt {
								width: parent.width
								text: card.summary
								bold: true
								visible: text !== ""
							}

							Text {
								width: parent.width
								visible: text !== ""
								text: card.body
								textFormat: Text.StyledText
								wrapMode: Text.WordWrap
								maximumLineCount: 4
								elide: Text.ElideRight
								color: Theme.fgDim
								linkColor: Theme.primary
								font.family: Theme.font
								font.pixelSize: Theme.fontSize
								onLinkActivated: link => Qt.openUrlExternally(link)
							}

							Flow {
								width: parent.width
								spacing: Theme.spacing
								visible: card.buttons.length > 0
								Repeater {
									model: card.buttons
									Btn {
										required property var modelData
										height: 26
										text: modelData.text
										onClicked: Notifs.invoke(card.w, modelData)
									}
								}
							}
						}
					}
				}
			}
		}
	}
}
