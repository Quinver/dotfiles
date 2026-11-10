pragma Singleton
import QtQuick
import Quickshell

// Shared minute-precision clock for every bar and the calendar panel.
Singleton {
	readonly property date date: clock.date

	SystemClock { id: clock; precision: SystemClock.Minutes }
}
