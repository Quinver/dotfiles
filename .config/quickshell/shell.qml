//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import "bar"
import "popouts"
import "wallpaper"

ShellRoot {
	id: shell

	Component.onCompleted: SystemTheme.start()

	Variants { model: Quickshell.screens; Background {} }
	Variants { model: Quickshell.screens; Bar {} }
	Variants { model: Quickshell.screens; PopoutHost {} }

	// Overlays live in overlays/<Name>.qml. They are loaded only if present so
	// the shell still starts while one of them is broken.
	Variants {
		model: ["Launcher", "PowerMenu", "Osd", "NotificationPopups"]
		Loader {
			required property string modelData
			source: Qt.resolvedUrl("overlays/" + modelData + ".qml")
			onStatusChanged: if (status === Loader.Error) console.warn("overlay failed to load:", modelData)
		}
	}

	// qs ipc call shell <function> [args]
	IpcHandler {
		target: "shell"
		function popout(name: string): void { Ui.toggle(name); }
		function overlay(name: string): void { Ui.toggleOverlay(name); }
		function close(): void { Ui.close(); }
		function theme(name: string): void { Settings.setTheme(name); }
		function nextTheme(): void { Settings.nextTheme(); }
		function safe(): void { Settings.toggleSafe(); }
		function wallpaper(action: string): void {
			if (action === "next") Wallpapers.next();
			else if (action === "prev") Wallpapers.prev();
			else if (action === "pause") Wallpapers.togglePause();
		}
		function currentTheme(): string { return Settings.themeName; }
	}
}
