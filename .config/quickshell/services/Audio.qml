pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// PipeWire state for the shell: default sink/source volume + mute, the device
// and per-app stream lists, and `osdTick`, which increments whenever the output
// volume or mute changes after startup (keyboard keys go through wpctl, so
// this is how the OSD notices them). Read from bar modules / popouts / the OSD.
Singleton {
	id: root

	readonly property var sink: Pipewire.defaultAudioSink
	readonly property var source: Pipewire.defaultAudioSource

	readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
	readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
	readonly property real micVolume: source && source.audio ? source.audio.volume : 0
	readonly property bool micMuted: source && source.audio ? source.audio.muted : false

	// Hardware / virtual devices (not streams) and per-app playback streams.
	readonly property var sinks: Pipewire.nodes.values.filter(n => !n.isStream && n.type === PwNodeType.AudioSink)
	readonly property var sources: Pipewire.nodes.values.filter(n => !n.isStream && n.type === PwNodeType.AudioSource)
	readonly property var streams: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioOutStream && String(n.name || "").indexOf("speech-dispatcher") !== 0)

	// Incremented on output volume / mute changes after startup.
	property int osdTick: 0

	PwObjectTracker { objects: [root.sink, root.source].concat(root.sinks, root.sources, root.streams) }

	function label(node) {
		return node ? (node.description || node.nickname || node.name) : "";
	}

	function streamName(node) {
		var p = node.properties || ({});
		return p["application.name"] || node.description || node.name;
	}

	function streamIcon(node) {
		var p = node.properties || ({});
		return p["application.icon-name"] || p["application.process.binary"] || p["application.name"] || "";
	}

	function setVolume(v) {
		if (!sink || !sink.audio) return;
		var c = Math.max(0, Math.min(1, v));
		sink.audio.volume = c;
		if (c > 0) sink.audio.muted = false;
	}
	function changeVolume(delta) { setVolume(volume + delta); }
	function toggleMute() { if (sink && sink.audio) sink.audio.muted = !sink.audio.muted; }

	function setMicVolume(v) {
		if (source && source.audio) source.audio.volume = Math.max(0, Math.min(1, v));
	}
	function toggleMicMute() { if (source && source.audio) source.audio.muted = !source.audio.muted; }

	function setDefaultSink(node) { Pipewire.preferredDefaultAudioSink = node; }
	function setDefaultSource(node) { Pipewire.preferredDefaultAudioSource = node; }

	// Changes in the first second, or right after the bound sink / its audio
	// object changes, are binding noise rather than user action.
	property bool armed: false
	readonly property var sinkAudio: sink ? sink.audio : null
	onSinkAudioChanged: { armed = false; settle.interval = 400; settle.restart(); }
	Timer { id: settle; interval: 1000; running: true; onTriggered: root.armed = true }

	Connections {
		target: root.sinkAudio
		function onVolumeChanged() { if (root.armed) root.osdTick++; }
		function onMutedChanged() { if (root.armed) root.osdTick++; }
	}
}
