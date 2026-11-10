import QtQuick
import qs.config
import qs.services
import qs.widgets

// AI button: opens the AI panel (local LLM controls + Claude / opencode usage).
// Middle click still toggles the local LLM directly; the colour shows its state.
BarButton {
	property var screen
	icon: Icons.robot
	popout: "ai"
	color: Llm.state === "up" ? Theme.ok : Llm.state === "connecting" ? Theme.warn : Llm.state === "unhealthy" ? Theme.error : Theme.fgDim
	text: Llm.state === "up" ? "LLM" : Llm.state === "connecting" ? "…" : Llm.state === "unhealthy" ? "!" : ""
	onMiddleClicked: if (Llm.available) Llm.toggle()
}
