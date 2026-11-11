import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Network popout: wifi toggle, status card with live rates, wifi list with
// inline password entry, WireGuard/VPN toggles, speed test. Scanning and rate sampling only run while it is open.
Column {
	id: root

	property string pwFor: ""       // network whose password row is open
	property string forgetFor: ""   // network waiting for a second click to forget

	width: Theme.popoutWidth
	spacing: Theme.spacing

	Component.onCompleted: { Net.watchers++; Net.scan(true); }
	Component.onDestruction: { Net.watchers--; Net.scan(false); }

	Timer { id: forgetTimer; interval: 3000; onTriggered: root.forgetFor = "" }

	function activate(network) {
		root.forgetFor = "";
		if (network.connected) Net.disconnect(network);
		else if (network.known || !Net.secured(network)) { root.pwFor = ""; Net.connect(network, ""); }
		else root.pwFor = root.pwFor === network.name ? "" : network.name;
	}

	// "wg-NL-FREE-2" -> "NL"; falls back to "VPN".
	function country(name) {
		var m = /^[a-z]+-([A-Za-z]{2})-/.exec(name);
		return m ? m[1].toUpperCase() : "VPN";
	}

	function kindText() {
		return Net.kind === "ethernet" ? "Ethernet" : Net.kind === "wifi" ? "Wi-Fi"
			: Net.kind === "none" ? "Not connected" : "Wi-Fi off";
	}

	Header {
		width: parent.width
		title: "Network"
		Toggle { checked: Net.wifiEnabled; onToggled: v => Net.setWifiEnabled(v) }
	}

	Box {
		width: parent.width
		level: 2
		small: true
		implicitHeight: card.implicitHeight + Theme.pad * 2

		Column {
			id: card
			anchors.fill: parent
			anchors.margins: Theme.pad
			spacing: 2

			Row {
				spacing: Theme.spacing
				Icon {
					glyph: Net.kind === "ethernet" ? Icons.ethernet : Net.kind === "wifi" ? Icons.wifi : Icons.ban
					color: Net.connected ? Theme.primary : Theme.fgMuted
					anchors.verticalCenter: parent.verticalCenter
				}
				Txt { text: root.kindText(); bold: true; anchors.verticalCenter: parent.verticalCenter }
				Txt {
					visible: Net.connected
					text: Net.kind === "wifi" ? Net.ssid : Net.iface
					dim: true
					anchors.verticalCenter: parent.verticalCenter
				}
			}
			Txt { visible: Net.connected && Net.ip !== ""; text: Net.ip; mono: true; dim: true; size: Theme.fontSmall }
			Row {
				visible: Net.connected
				spacing: Theme.pad
				Row {
					spacing: 4
					Icon { glyph: Icons.arrowDown; size: Theme.fontSmall; color: Theme.ok; anchors.verticalCenter: parent.verticalCenter }
					Txt { text: Net.fmtRate(Net.rxRate); mono: true; size: Theme.fontSmall }
				}
				Row {
					spacing: 4
					Icon { glyph: Icons.arrowUp; size: Theme.fontSmall; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
					Txt { text: Net.fmtRate(Net.txRate); mono: true; size: Theme.fontSmall }
				}
			}
		}
	}

	Header { width: parent.width; title: "Wi-Fi" }

	Txt {
		visible: list.count === 0
		width: parent.width
		height: Theme.rowHeight
		horizontalAlignment: Text.AlignHCenter
		muted: true
		text: !Net.wifiDevice ? "No wireless adapter" : !Net.wifiEnabled ? "Wi-Fi is off" : "Scanning…"
	}

	ListView {
		id: list
		visible: count > 0
		width: parent.width
		height: Math.min(contentHeight, 320)
		clip: true
		model: Net.wifiEnabled ? Net.networks : []

		delegate: Column {
			id: row
			required property var modelData
			readonly property bool asking: root.forgetFor === modelData.name
			width: ListView.view.width

			ListItem {
				width: parent.width
				icon: Icons.wifi
				iconColor: row.modelData.connected ? Theme.primary : Theme.fgDim
				title: row.asking ? "Forget? click again" : row.modelData.name
				subtitle: row.modelData.stateChanging ? "Connecting…"
					: row.modelData.connected ? "Connected"
					: row.modelData.known ? "Saved" : Net.securityText(row.modelData)
				selected: row.modelData.connected
				opacity: 0.5 + 0.5 * Net.clamp(row.modelData.signalStrength)
				onClicked: if (row.asking) root.forgetFor = ""; else root.activate(row.modelData)
				onRightClicked: {
					if (!row.modelData.known) return;
					if (row.asking) { Net.forget(row.modelData); root.forgetFor = ""; }
					else { root.forgetFor = row.modelData.name; forgetTimer.restart(); }
				}
				Icon { visible: Net.secured(row.modelData); glyph: Icons.lock; size: Theme.fontSmall; color: Theme.fgMuted }
			}

			Txt {
				visible: Net.lastError !== "" && Net.errorNetwork === row.modelData.name
				width: parent.width
				leftPadding: Theme.pad
				height: visible ? implicitHeight + 4 : 0
				text: Net.lastError
				color: Theme.error
				size: Theme.fontSmall
			}

			Row {
				visible: root.pwFor === row.modelData.name
				width: parent.width
				height: visible ? Theme.rowHeight + Theme.spacing : 0
				spacing: Theme.spacing
				topPadding: Theme.spacing
				onVisibleChanged: if (visible) { pw.text = ""; pw.focusInput(); }

				Field {
					id: pw
					width: parent.width - go.width - Theme.spacing
					password: true
					icon: Icons.lock
					placeholder: "Password"
					onAccepted: go.clicked()
					Keys.onEscapePressed: root.pwFor = ""
				}
				Btn {
					id: go
					text: "Connect"
					accent: true
					onClicked: {
						if (pw.text === "") return;
						Net.connect(row.modelData, pw.text);
						root.pwFor = "";
					}
				}
			}
		}
	}

	Header { width: parent.width; title: "VPN" }

	Txt {
		visible: Net.vpns.length === 0
		width: parent.width
		height: Theme.rowHeight
		horizontalAlignment: Text.AlignHCenter
		muted: true
		text: "No VPN profiles"
	}

	Repeater {
		model: Net.vpns
		delegate: ListItem {
			id: vrow
			required property var modelData
			width: root.width
			icon: Icons.lock
			iconColor: modelData.active ? Theme.ok : Theme.fgDim
			title: modelData.name
			subtitle: root.country(modelData.name) + (modelData.active ? " · Connected" : "")
			selected: modelData.active
			onClicked: Net.setVpn(modelData.name, !modelData.active)
			Toggle { checked: vrow.modelData.active; onToggled: v => Net.setVpn(vrow.modelData.name, v) }
		}
	}

	Header {
		visible: Net.speedtestAvailable
		width: parent.width
		title: "Speed test"
		Btn {
			text: Net.speedResult ? "Run again" : "Run test"
			enabled: !Net.speedRunning
			implicitHeight: 24
			onClicked: Net.runSpeedtest()
		}
	}

	Column {
		visible: Net.speedRunning
		width: parent.width
		spacing: Theme.spacing
		Txt { text: "Testing…"; dim: true }
		Rectangle {
			width: parent.width
			height: 3
			color: Theme.surfaceTop
			clip: true
			Rectangle {
				id: sweep
				width: parent.width * 0.3
				height: parent.height
				color: Theme.primary
				SequentialAnimation on x {
					running: Net.speedRunning
					loops: Animation.Infinite
					NumberAnimation { from: -sweep.width; to: sweep.parent.width; duration: Theme.animSlow * 4; easing.type: Easing.InOutQuad }
				}
			}
		}
	}

	Txt {
		visible: !Net.speedRunning && Net.speedError !== ""
		width: parent.width
		text: Net.speedError
		color: Theme.error
		size: Theme.fontSmall
	}

	Txt {
		visible: Net.speedtestAvailable && !Net.speedRunning && !Net.speedResult && Net.speedError === ""
		width: parent.width
		height: Theme.rowHeight
		horizontalAlignment: Text.AlignHCenter
		muted: true
		text: "No test run yet"
	}

	Box {
		visible: !Net.speedRunning && Net.speedResult !== null
		width: parent.width
		level: 2
		small: true
		implicitHeight: res.implicitHeight + Theme.pad * 2

		Column {
			id: res
			anchors.fill: parent
			anchors.margins: Theme.pad
			spacing: Theme.spacing
			Row {
				width: parent.width
				Repeater {
					model: Net.speedResult ? [
						{ label: "Download", value: Net.speedResult.down.toFixed(0), unit: "Mbps", glyph: Icons.arrowDown, tint: Theme.ok },
						{ label: "Upload", value: Net.speedResult.up.toFixed(0), unit: "Mbps", glyph: Icons.arrowUp, tint: Theme.primary },
						{ label: "Ping", value: Net.speedResult.ping.toFixed(0), unit: "ms", glyph: Icons.clock, tint: Theme.fgDim }
					] : []
					delegate: Column {
						required property var modelData
						width: res.width / 3
						Row {
							spacing: 4
							Icon { glyph: modelData.glyph; size: Theme.fontSmall; color: modelData.tint; anchors.verticalCenter: parent.verticalCenter }
							Txt { text: modelData.label; muted: true; size: Theme.fontSmall }
						}
						Txt { text: modelData.value; size: Theme.fontHuge; bold: true; mono: true }
						Txt { text: modelData.unit; muted: true; size: Theme.fontSmall }
					}
				}
			}
			Txt {
				width: parent.width
				elide: Text.ElideRight
				dim: true
				size: Theme.fontSmall
				text: Net.speedResult ? Net.speedResult.server + " · " + Net.speedResult.isp + " · " + Qt.formatTime(Net.speedResult.time, "HH:mm") : ""
			}
		}
	}

	Sep { width: parent.width }

	Btn {
		visible: Deps.has("nm-connection-editor")
		width: parent.width
		flat: true
		icon: Icons.cog
		text: "Connection editor"
		onClicked: { Quickshell.execDetached(["nm-connection-editor"]); Ui.close(); }
	}
}
