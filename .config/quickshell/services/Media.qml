pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// MPRIS media state. `player` is the active player (playing > Spotify > last
// played > first, unless pinned with select()). The panel increments `watchers`
// while it shows the position so the 1 s position tick only runs when needed.
Singleton {
	id: root

	readonly property var players: Mpris.players.values
	property var pinned: null
	property var lastPlaying: null
	property int watchers: 0

	function isSpotify(p) {
		return p.desktopEntry === "spotify" || p.identity.indexOf("Spotify") >= 0;
	}

	readonly property var player: {
		var list = players;
		if (!list.length) return null;
		if (pinned && list.indexOf(pinned) >= 0) return pinned;
		var playing = list.filter(p => p.isPlaying);
		if (playing.length) return playing.find(isSpotify) || playing[0];
		if (lastPlaying && list.indexOf(lastPlaying) >= 0) return lastPlaying;
		return list.find(isSpotify) || list[0];
	}

	readonly property bool isSpotifyActive: player ? isSpotify(player) : false
	readonly property string title: player ? player.trackTitle : ""
	readonly property string artist: player ? player.trackArtist : ""
	readonly property string album: player ? player.trackAlbum : ""
	readonly property string artUrl: player ? player.trackArtUrl : ""
	readonly property bool playing: player ? player.isPlaying : false
	readonly property real length: player && player.lengthSupported ? player.length : 0
	readonly property real position: player && player.positionSupported ? player.position : 0
	readonly property bool canSeek: player ? player.canSeek && player.positionSupported && player.lengthSupported : false
	readonly property bool shuffle: player ? player.shuffle : false
	readonly property int loop: player ? player.loopState : MprisLoopState.None

	function select(p) { pinned = p; }

	function toggle() { if (player && player.canTogglePlaying) player.togglePlaying(); }
	function next() { if (player && player.canGoNext) player.next(); }
	function previous() { if (player && player.canGoPrevious) player.previous(); }
	function seekTo(seconds) { if (canSeek) player.position = Math.max(0, Math.min(length, seconds)); }
	function toggleShuffle() { if (player && player.shuffleSupported) player.shuffle = !player.shuffle; }
	function cycleLoop() {
		if (!player || !player.loopSupported) return;
		player.loopState = loop === MprisLoopState.None ? MprisLoopState.Playlist
			: loop === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
	}
	function setVolume(v) { if (player && player.volumeSupported) player.volume = Math.max(0, Math.min(1, v)); }
	function raise() { if (player && player.canRaise) player.raise(); }

	// Remember the most recent player that was playing.
	Instantiator {
		model: Mpris.players
		delegate: QtObject {
			required property var modelData
			property bool isPlaying: modelData.isPlaying
			onIsPlayingChanged: if (isPlaying) root.lastPlaying = modelData
			Component.onCompleted: if (isPlaying) root.lastPlaying = modelData
		}
	}

	// MPRIS does not push position continuously; re-read it once a second.
	Timer {
		interval: 1000
		repeat: true
		running: root.watchers > 0 && root.playing
		onTriggered: root.player.positionChanged()
	}
}
