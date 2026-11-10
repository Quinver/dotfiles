pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config

// Notification daemon + model. This shell owns org.freedesktop.Notifications.
//
//   Notifs.popups            wrappers shown as popups now (newest first, max 5)
//   Notifs.list              wrappers in the notification centre (newest first, max 100)
//   Notifs.count / hasCritical / dnd
//   Notifs.dismiss(w) / dismissAll() / hidePopup(w) / invoke(w, action) / toggleDnd()
//   Notifs.icon(w) / timeAgo(date)
//
// A wrapper is a plain object { n: <Notification>, id, key (unique int), time: Date, popup: bool,
// remaining: ms left as popup (-1 = never), paused: bool }. Read content live
// from `w.n` (summary, body, ...). `popups` and `list` are JS arrays that are
// REPLACED (never mutated) on every change so bindings update.
//
// expireTimeout assumption (not documented in the installed qmltypes): the
// property is in SECONDS; a value < 0 (-1) means "server default" and 0 means
// "never expires" per the freedesktop spec.
Singleton {
	id: root

	readonly property int maxPopups: 5
	readonly property int maxList: 100
	property int _seq: 0

	property var list: []
	property var popups: []
	readonly property int count: list.length
	readonly property bool hasCritical: list.some(w => w.n.urgency === NotificationUrgency.Critical)
	readonly property bool dnd: !!Settings.state.dnd

	function toggleDnd() { Settings.setState("dnd", !root.dnd); }

	// ---- model ----

	// Popup lifetime in ms for a notification, -1 = never auto-hides.
	function timeoutMs(n) {
		if (n.urgency === NotificationUrgency.Critical) return -1;
		if (n.urgency === NotificationUrgency.Low) return 3000;
		var t = n.expireTimeout;
		if (t === 0) return -1;
		if (t > 0) return Math.round(t * 1000);
		return Math.round(Settings.opt("notifyTimeout", 6) * 1000);
	}

	function _publish(all) {
		root.list = all;
		root.popups = all.filter(w => w.popup).slice(0, root.maxPopups);
		tick.running = root.popups.length > 0;
	}

	// Adds a notification (real or fake) and returns its wrapper.
	function _add(n) {
		for (var i = 0; i < root.list.length; i++) if (root.list[i].n === n) return root.list[i];
		var w = {
			n: n, id: n.id, key: ++root._seq, time: new Date(),
			popup: !root.dnd || n.urgency === NotificationUrgency.Critical,
			remaining: timeoutMs(n), paused: false
		};
		var all = [w].concat(root.list);
		for (var j = all.length - 1; j >= root.maxList; j--) {
			// over the cap: drop the oldest (dismiss the live object so the sender is told)
			var old = all.pop();
			if (old.n.dismiss) old.n.dismiss();
		}
		_publish(all);
		return w;
	}

	function _remove(w) { _publish(root.list.filter(x => x !== w)); }

	function hidePopup(w) {
		if (!w.popup) return;
		w.popup = false;
		if (w.n.transient) dismiss(w);
		else _publish(root.list.slice());
	}

	function dismiss(w) {
		_remove(w);
		if (w.n.dismiss) w.n.dismiss();
	}

	function dismissAll() {
		var all = root.list;
		_publish([]);
		for (var i = 0; i < all.length; i++) if (all[i].n.dismiss) all[i].n.dismiss();
	}

	function invoke(w, action) {
		action.invoke();
		if (!w.n.resident) dismiss(w);
	}

	// Hover support for popups: a hovered popup does not count down.
	function setPaused(w, paused) { w.paused = paused; }

	// Advances popup timers by `ms`; hides those that ran out.
	function _tick(ms) {
		var expired = root.popups.filter(function (w) {
			if (w.paused || w.remaining < 0) return false;
			w.remaining -= ms;
			return w.remaining <= 0;
		});
		for (var i = 0; i < expired.length; i++) hidePopup(expired[i]);
	}

	Timer {
		id: tick
		interval: 200
		repeat: true
		onTriggered: root._tick(interval)
	}

	// ---- server ----

	NotificationServer {
		keepOnReload: true
		persistenceSupported: true
		bodySupported: true
		bodyMarkupSupported: true
		actionsSupported: true
		imageSupported: true

		onNotification: function (n) {
			n.tracked = true;
			var w = root._add(n);
			n.closed.connect(function () { root._remove(w); });
		}
	}

	// ---- helpers ----

	function isDefault(action) { return action.identifier === "default"; }

	function defaultAction(w) {
		if (!w || !w.n) return null;
		var a = w.n.actions || [];
		for (var i = 0; i < a.length; i++) if (isDefault(a[i])) return a[i];
		return null;
	}

	function buttonActions(w) { return (!w || !w.n) ? [] : (w.n.actions || []).filter(a => !isDefault(a)); }

	function icon(w) {
		if (!w || !w.n) return "";
		var n = w.n;
		if (n.image) return n.image;
		var p = _resolve(n.appIcon);
		if (p) return p;
		var key = n.desktopEntry || n.appName;
		if (key) {
			var e = DesktopEntries.heuristicLookup(key);
			if (e && e.icon) return _resolve(e.icon);
		}
		return "";
	}

	function _resolve(name) {
		if (!name) return "";
		if (name.indexOf("/") === 0 || name.indexOf("file:") === 0 || name.indexOf("image://") === 0) return name;
		return Quickshell.iconPath(name, true);
	}

	function timeAgo(date) {
		var s = Math.max(0, (Date.now() - date.getTime()) / 1000);
		if (s < 60) return "now";
		if (s < 3600) return Math.floor(s / 60) + "m";
		if (s < 86400) return Math.floor(s / 3600) + "h";
		return Math.floor(s / 86400) + "d";
	}
}
