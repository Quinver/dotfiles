import QtQuick
import qs.config
import qs.services
import qs.widgets

// Now-playing item: icon + "Title - Artist". Middle = play/pause,
// scroll = next/previous (debounced), right = next.
BarButton {
	property var screen

	visible: Media.player !== null
	popout: "media"
	icon: Media.isSpotifyActive ? Icons.spotify : Icons.music
	text: Media.artist !== "" ? Media.title + " — " + Media.artist : Media.title
	color: Media.playing ? Theme.primary : Theme.fgDim

	onMiddleClicked: Media.toggle()
	onRightClicked: Media.next()
	onScrolled: delta => {
		if (wheelLock.running) return;
		wheelLock.start();
		if (delta > 0) Media.previous(); else Media.next();
	}
	Timer { id: wheelLock; interval: 450 }

	// BarButton's label does not elide, so elide the string itself to ~220 px.
	TextMetrics {
		id: metrics
		font.family: Theme.font
		font.pixelSize: Theme.fontSize
		elide: Text.ElideRight
		elideWidth: 220
		text: Media.artist !== "" ? Media.title + " \u2014 " + Media.artist : Media.title
	}
}
