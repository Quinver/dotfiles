//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import "bar"
import "popouts"
import "wallpaper"
import "desktop"

ShellRoot {
	id: shell

	Component.onCompleted: SystemTheme.start()

	Variants { model: Quickshell.screens; Background {} }
	Variants { model: Quickshell.screens; DesktopWidgets {} }
	Variants { model: Quickshell.screens; Bar {} }
	Variants { model: Quickshell.screens; PopoutHost {} }

	// Overlays live in overlays/<Name>.qml. They are loaded only if present so
	// the shell still starts while one of them is broken.
	Variants {
		model: ["Launcher", "PowerMenu", "Osd", "NotificationPopups", "ThemeStudio", "Capture", "Overview", "Keys", "Mixer", "Games", "Tasks", "Docker"]
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
		function shot(mode: string, action: string): void { Capture.shot(mode, action); }
		function record(): void { Capture.toggleRecord(); }
		function currentTheme(): string { return Settings.themeName; }
	}
}
