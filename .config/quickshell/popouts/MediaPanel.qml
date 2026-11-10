import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.config
import qs.services
import qs.widgets

// "Spotify settings" popout: now playing, seek, transport, player volume.
Column {
	id: root

	width: Theme.popoutWidth
	spacing: Theme.spacing

	function fmt(s) {
		var t = Math.max(0, Math.floor(s));
		var m = Math.floor(t / 60), sec = t % 60;
		return m + ":" + (sec < 10 ? "0" : "") + sec;
	}

	// Keep the position ticking while this panel exists.
	Component.onCompleted: Media.watchers++
	Component.onDestruction: Media.watchers--

	Txt {
		visible: Media.player === null
		width: parent.width
		height: Theme.rowHeight * 2
		text: "No media player running"
		muted: true
		horizontalAlignment: Text.AlignHCenter
	}

	// Player selector, only when there is a choice.
	Row {
		visible: Media.players.length > 1
		spacing: Theme.spacing
		Repeater {
			model: Media.players
			Btn {
				required property var modelData
				text: modelData.identity
				checked: modelData === Media.player
				onClicked: Media.select(modelData)
			}
		}
	}

	RowLayout {
		visible: Media.player !== null
		width: parent.width
		spacing: Theme.pad

		Box {
			Layout.preferredWidth: 96
			Layout.preferredHeight: 96
			level: 2
			small: true
			clip: true
			Image {
				anchors.fill: parent
				visible: status === Image.Ready
				source: Media.artUrl
				fillMode: Image.PreserveAspectCrop
				asynchronous: true
			}
			Icon { anchors.centerIn: parent; glyph: Icons.music; size: 32; color: Theme.fgMuted; visible: Media.artUrl === "" }
		}

		Column {
			Layout.fillWidth: true
			Layout.alignment: Qt.AlignVCenter
			spacing: 2
			Txt { width: parent.width; text: Media.title || "Unknown title"; size: Theme.fontLarge; bold: true }
			Txt { width: parent.width; text: Media.artist; dim: true; visible: text !== "" }
			Txt { width: parent.width; text: Media.album; muted: true; size: Theme.fontSmall; visible: text !== "" }
		}
	}

	Column {
		visible: Media.player !== null
		width: parent.width
		Slider {
			width: parent.width
			enabled: Media.canSeek
			value: Media.length > 0 ? Media.position / Media.length : 0
			onMoved: v => Media.seekTo(v * Media.length)
		}
		Item {
			width: parent.width
			height: elapsed.implicitHeight
			Txt { id: elapsed; text: root.fmt(Media.position); mono: true; muted: true; size: Theme.fontSmall }
			Txt { anchors.right: parent.right; text: root.fmt(Media.length); mono: true; muted: true; size: Theme.fontSmall }
		}
	}

	Row {
		visible: Media.player !== null
		anchors.horizontalCenter: parent.horizontalCenter
		spacing: Theme.spacing
		Btn { icon: Icons.shuffle; flat: true; checked: Media.shuffle; enabled: Media.player !== null && Media.player.shuffleSupported; onClicked: Media.toggleShuffle() }
		Btn { icon: Icons.previous; flat: true; enabled: Media.player !== null && Media.player.canGoPrevious; onClicked: Media.previous() }
		Btn { icon: Media.playing ? Icons.pause : Icons.play; accent: true; implicitWidth: Theme.rowHeight * 1.6; onClicked: Media.toggle() }
		Btn { icon: Icons.next; flat: true; enabled: Media.player !== null && Media.player.canGoNext; onClicked: Media.next() }
		Btn {
			icon: Icons.loop
			text: Media.loop === MprisLoopState.Track ? "1" : ""
			flat: true
			checked: Media.loop !== MprisLoopState.None
			enabled: Media.player !== null && Media.player.loopSupported
			onClicked: Media.cycleLoop()
		}
	}

	RowLayout {
		visible: Media.player !== null && Media.player.volumeSupported
		width: parent.width
		spacing: Theme.spacing
		Icon { glyph: Icons.volumeLow; color: Theme.fgDim }
		Slider { Layout.fillWidth: true; value: Media.player ? Media.player.volume : 0; onMoved: v => Media.setVolume(v) }
	}

	Btn {
		visible: Media.player !== null && Media.player.canRaise
		text: "Open player"
		flat: true
		width: parent.width
		onClicked: { Media.raise(); Ui.close(); }
	}
}
