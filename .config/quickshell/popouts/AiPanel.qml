import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// AI panel: local LLM (llama.cpp container) controls on top, then a
// Claude / opencode switch showing usage for the selected tool.
Column {
	id: root

	width: Theme.popoutWidth
	spacing: Theme.spacing

	readonly property string tab: Settings.state.aiTab === "opencode" ? "opencode" : "claude"
	readonly property bool isClaude: tab === "claude"
	readonly property var c: AiUsage.claude
	readonly property var o: AiUsage.opencode
	readonly property var ocToday: o.today || ({})
	readonly property var ocWeek: o.week || ({})

	function openIn(cmd) {
		Quickshell.execDetached([Settings.opt("terminal", "alacritty"), "-e", cmd]);
		Ui.close();
	}

	readonly property var limits: c.limits || ({})
	readonly property bool limitsLive: limits.source === "api"

	// "in 2h 10m" / "in 3d 4h" until an ISO timestamp.
	function until(iso) {
		var m = Math.floor((new Date(iso).getTime() - Date.now()) / 60000);
		if (isNaN(m) || m <= 0) return "now";
		if (m < 60) return "in " + m + "m";
		if (m < 1440) return "in " + Math.floor(m / 60) + "h " + (m % 60) + "m";
		return "in " + Math.floor(m / 1440) + "d " + Math.floor((m % 1440) / 60) + "h";
	}

	function ago(iso) {
		if (!iso) return "never";
		var m = Math.floor((Date.now() - new Date(iso).getTime()) / 60000);
		if (m < 1) return "just now";
		if (m < 60) return m + "m ago";
		if (m < 1440) return Math.floor(m / 60) + "h ago";
		return Math.floor(m / 1440) + "d ago";
	}

	Component.onCompleted: { AiUsage.watchers++; AiUsage.refresh(); }
	Component.onDestruction: AiUsage.watchers--

	component Stat: Row {
		property string label: ""
		property string value: ""
		width: root.width
		height: 20
		Txt { width: parent.width * 0.5; text: parent.label; dim: true; anchors.verticalCenter: parent.verticalCenter }
		Txt { width: parent.width * 0.5; text: parent.value; mono: true; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
	}

	component ModelRows: Column {
		property var models: []
		width: root.width
		spacing: 2
		Repeater {
			model: parent.models
			Stat {
				required property var modelData
				label: modelData.name
				value: AiUsage.fmt(modelData.tokens) + " · " + modelData.messages
			}
		}
		Txt { visible: parent.models.length === 0; text: "No activity"; muted: true }
	}

	// ---- Local LLM ----
	Header {
		width: parent.width
		title: "Local LLM"
		Txt {
			text: !Llm.available ? "not set up" : Llm.state === "up" ? "running" : Llm.state === "connecting" ? "loading model…" : Llm.state === "unhealthy" ? "unhealthy" : "stopped"
			color: Llm.state === "up" ? Theme.ok : Llm.state === "connecting" ? Theme.warn : Llm.state === "unhealthy" ? Theme.error : Theme.fgMuted
			size: Theme.fontSmall
		}
	}
	Row {
		width: parent.width
		spacing: Theme.spacing
		Btn {
			width: (parent.width - parent.spacing) / 2
			enabled: Llm.available
			icon: Llm.state === "off" ? Icons.play : Icons.stop
			text: Llm.state === "off" ? "Start" : "Stop"
			accent: Llm.state === "off" && Llm.available
			onClicked: Llm.toggle()
		}
		Btn {
			width: (parent.width - parent.spacing) / 2
			enabled: Llm.available && Llm.state !== "off"
			icon: Icons.refresh
			text: "Restart"
			onClicked: Llm.restart()
		}
	}
	Txt { width: parent.width; text: Llm.container; mono: true; muted: true; size: Theme.fontSmall }

	Sep { width: parent.width }

	// ---- Claude / opencode ----
	Row {
		width: parent.width
		spacing: Theme.spacing
		Btn { width: (parent.width - parent.spacing) / 2; text: "Claude"; checked: root.isClaude; onClicked: Settings.setState("aiTab", "claude") }
		Btn { width: (parent.width - parent.spacing) / 2; text: "opencode"; checked: !root.isClaude; onClicked: Settings.setState("aiTab", "opencode") }
	}

	Txt {
		visible: AiUsage.loading && !AiUsage.info.generated
		text: "Reading usage…"
		muted: true
	}

	// Claude
	Column {
		visible: root.isClaude && !!AiUsage.info.generated
		width: parent.width
		spacing: Theme.spacing

		Txt { visible: !root.c.available; text: "No Claude Code data found"; muted: true }

		// Plan limits: real figures from Anthropic, or a local estimate with a warning.
		Header {
			width: parent.width
			title: "Limits"
			Txt { visible: !root.limitsLive; text: "estimate"; color: Theme.warn; size: Theme.fontSmall }
		}
		Row {
			visible: !root.limitsLive
			width: parent.width
			spacing: 6
			Icon { glyph: Icons.warning; color: Theme.warn; size: Theme.fontSize; anchors.verticalCenter: parent.verticalCenter }
			Txt {
				width: parent.width - Theme.fontSize - 10
				wrapMode: Text.WordWrap
				elide: Text.ElideNone
				color: Theme.warn
				size: Theme.fontSmall
				text: "Local estimate from this machine's transcripts; real limits unavailable"
					+ (root.limits.warning ? " (" + root.limits.warning + ")" : "") + "."
			}
		}
		Repeater {
			model: root.limits.rows || []
			Column {
				required property var modelData
				width: root.width
				spacing: 3
				Row {
					width: parent.width
					height: 18
					Txt { width: parent.width * 0.4; text: modelData.label; dim: true }
					Txt {
						width: parent.width * 0.6
						horizontalAlignment: Text.AlignRight
						mono: true
						text: root.limitsLive
							? Math.round(modelData.pct) + "% used" + (modelData.resetsAt ? " · resets " + root.until(modelData.resetsAt) : "")
							: AiUsage.fmt(modelData.tokens) + " tokens"
					}
				}
				Meter { visible: root.limitsLive; width: parent.width; value: (modelData.pct || 0) / 100 }
			}
		}

		Header { width: parent.width; title: "Today"; Txt { text: "last active " + root.ago(root.c.lastActive); size: Theme.fontSmall; muted: true } }
		Stat { label: "Output tokens"; value: AiUsage.fmt((root.c.today || {}).output) }
		Stat { label: "Input + cache write"; value: AiUsage.fmt(((root.c.today || {}).input || 0) + ((root.c.today || {}).cacheWrite || 0)) }
		Stat { label: "Cache read"; value: AiUsage.fmt((root.c.today || {}).cacheRead) }
		Stat { label: "Replies · sessions"; value: ((root.c.today || {}).messages || 0) + " · " + (root.c.sessionsToday || 0) }

		Header { width: parent.width; title: "Last 7 days"; Txt { text: (root.c.sessionsWeek || 0) + " sessions"; size: Theme.fontSmall; muted: true } }
		Graph {
			width: parent.width
			height: 44
			values: (root.c.daily || []).map(d => d.tokens)
			max: Math.max(1, Math.max.apply(null, (root.c.daily || [{ tokens: 1 }]).map(d => d.tokens)))
		}
		Stat { label: "Output tokens"; value: AiUsage.fmt((root.c.week || {}).output) }
		Stat { label: "Input + cache write"; value: AiUsage.fmt(((root.c.week || {}).input || 0) + ((root.c.week || {}).cacheWrite || 0)) }

		Header { width: parent.width; title: "Models (7 days)"; Txt { text: "tokens · replies"; size: Theme.fontSmall; muted: true } }
		ModelRows { models: root.c.models || [] }

		Btn { width: parent.width; flat: true; icon: Icons.terminal; text: "Open Claude Code"; onClicked: root.openIn("claude") }
	}

	// opencode
	Column {
		visible: !root.isClaude && !!AiUsage.info.generated
		width: parent.width
		spacing: Theme.spacing

		Txt { visible: !root.o.available; text: "opencode is not installed"; muted: true }

		Header { width: parent.width; title: "Today" }
		Stat { label: "Prompts · steps"; value: (root.ocToday.prompts || 0) + " · " + (root.ocToday.steps || 0) }
		Stat { label: "Output tokens"; value: AiUsage.fmt(root.ocToday.output) }
		Stat { label: "Input tokens"; value: AiUsage.fmt(root.ocToday.input) }

		Header { width: parent.width; title: "Last 7 days"; Txt { text: (root.ocWeek.sessions || 0) + " sessions"; size: Theme.fontSmall; muted: true } }
		Stat { label: "Prompts · steps"; value: (root.ocWeek.prompts || 0) + " · " + (root.ocWeek.steps || 0) }
		Stat { label: "Output tokens"; value: AiUsage.fmt(root.ocWeek.output) }
		Stat { label: "Input tokens"; value: AiUsage.fmt(root.ocWeek.input) }
		Stat { label: "Cache read"; value: AiUsage.fmt(root.ocWeek.cacheRead) }
		Stat { label: "Tool calls · failed"; value: (root.ocWeek.toolCalls || 0) + " · " + (root.ocWeek.toolFailed || 0) }
		Stat { label: "Cost"; value: "$" + (Number(root.ocWeek.cost) || 0).toFixed(2) }

		Header { width: parent.width; title: "Models (7 days)"; Txt { text: "tokens · steps"; size: Theme.fontSmall; muted: true } }
		ModelRows { models: root.ocWeek.models || [] }

		Btn { width: parent.width; flat: true; icon: Icons.terminal; text: "Open opencode"; onClicked: root.openIn("opencode") }
	}
}
