import QtQuick
import qs.config
import qs.services
import Quickshell
import qs.widgets

// Notification centre: DND toggle, clear-all and the list of kept notifications.
Column {
	id: root
	width: Theme.popoutWidth
	spacing: Theme.spacing

	// re-evaluates the "5m" labels once a minute
	SystemClock { id: clock; precision: SystemClock.Minutes }

	Header {
		width: parent.width
		title: "Notifications"
		Txt { text: "DND"; size: Theme.fontSmall; muted: true; anchors.verticalCenter: parent.verticalCenter }
		Toggle {
			anchors.verticalCenter: parent.verticalCenter
			checked: Notifs.dnd
			onToggled: Notifs.toggleDnd()
		}
		Btn {
			text: "Clear"
			flat: true
			enabled: Notifs.count > 0
			height: 24
			onClicked: Notifs.dismissAll()
		}
	}

	Sep { width: parent.width }

	Item {
		width: parent.width
		height: 120
		visible: Notifs.count === 0
		Column {
			anchors.centerIn: parent
			spacing: Theme.spacing
			Icon { anchors.horizontalCenter: parent.horizontalCenter; glyph: Icons.bell; size: Theme.fontHuge; color: Theme.fgMuted }
			Txt { anchors.horizontalCenter: parent.horizontalCenter; text: "No notifications"; muted: true }
		}
	}

	ListView {
		id: view
		width: parent.width
		height: Math.min(contentHeight, 480)
		visible: Notifs.count > 0
		clip: true
		boundsBehavior: Flickable.StopAtBounds
		model: Notifs.list

		delegate: Column {
			id: item
			required property var modelData
			required property int index
			readonly property var w: modelData
			readonly property var n: w.n
			readonly property bool sameApp: index > 0 && Notifs.list[index - 1].n.appName === n.appName
			readonly property var defAction: Notifs.defaultAction(w)
			readonly property var buttons: Notifs.buttonActions(w)
			readonly property string iconSource: Notifs.icon(w)
			width: view.width

			Sep { width: parent.width; visible: index > 0 }

			Item {
				width: parent.width
				height: body.implicitHeight + Theme.pad * 2
				Rectangle { anchors.fill: parent; color: Theme.surfaceHi; opacity: rowHover.hovered ? 1 : 0 }
				HoverHandler { id: rowHover }
				MouseArea {
					anchors.fill: parent
					onClicked: item.defAction ? Notifs.invoke(item.w, item.defAction) : null
				}

				Column {
					id: body
					x: Theme.pad
					y: Theme.pad
					width: parent.width - Theme.pad * 2
					spacing: 3

					Item {
						width: parent.width
						height: item.sameApp ? 0 : 22
						visible: !item.sameApp
						Image {
							id: img
							anchors.left: parent.left
							anchors.verticalCenter: parent.verticalCenter
							width: 16
							height: 16
							source: item.iconSource
							sourceSize: Qt.size(32, 32)
							asynchronous: true
							visible: status === Image.Ready
						}
						Txt {
							anchors.left: img.visible ? img.right : parent.left
							anchors.leftMargin: img.visible ? Theme.spacing : 0
							anchors.right: ago.left
							anchors.verticalCenter: parent.verticalCenter
							text: item.n.appName
							size: Theme.fontSmall
							muted: true
						}
						Txt {
							id: ago
							anchors.right: close.left
							anchors.verticalCenter: parent.verticalCenter
							text: (clock.date, Notifs.timeAgo(item.w.time))
							size: Theme.fontSmall
							muted: true
						}
						Btn {
							id: close
							anchors.right: parent.right
							anchors.verticalCenter: parent.verticalCenter
							width: 22
							height: 22
							flat: true
							icon: Icons.close
							iconSize: Theme.fontSmall
							onClicked: Notifs.dismiss(item.w)
						}
					}

					Item {
						// grouped item: no app header, so keep the time and close button reachable
						width: parent.width
						height: item.sameApp ? 22 : 0
						visible: item.sameApp
						Txt {
							anchors.right: close2.left
							anchors.verticalCenter: parent.verticalCenter
							text: (clock.date, Notifs.timeAgo(item.w.time))
							size: Theme.fontSmall
							muted: true
						}
						Btn {
							id: close2
							anchors.right: parent.right
							anchors.verticalCenter: parent.verticalCenter
							width: 22
							height: 22
							flat: true
							icon: Icons.close
							iconSize: Theme.fontSmall
							onClicked: Notifs.dismiss(item.w)
						}
					}

					Txt {
						width: parent.width
						text: item.n.summary
						bold: true
						visible: text !== ""
					}

					Text {
						width: parent.width
						visible: text !== ""
						text: item.n.body
						textFormat: Text.StyledText
						wrapMode: Text.WordWrap
						maximumLineCount: 6
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
						visible: item.buttons.length > 0
						Repeater {
							model: item.buttons
							Btn {
								required property var modelData
								height: 26
								text: modelData.text
								onClicked: Notifs.invoke(item.w, modelData)
							}
						}
					}
				}
			}
		}
	}
}
