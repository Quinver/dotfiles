import QtQuick
import qs.config
import qs.services
import qs.widgets

// AI button (hidden when neither the local LLM nor usage data is available): opens the AI panel (local LLM controls + Claude / opencode usage).
// Middle click still toggles the local LLM directly; the colour shows its state.
BarButton {
	property var screen
	visible: Ui.usable("ai")
	width: visible ? implicitWidth : 0
	icon: Icons.robot
	popout: "ai"
	color: Llm.state === "up" ? Theme.ok : Llm.state === "connecting" ? Theme.warn : Llm.state === "unhealthy" ? Theme.error : Theme.fgDim
	text: Llm.state === "up" ? "LLM" : Llm.state === "connecting" ? "…" : Llm.state === "unhealthy" ? "!" : ""
	onMiddleClicked: if (Llm.available) Llm.toggle()
}
