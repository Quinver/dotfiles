pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.services

// Launcher data: installed apps, ranked search, launch frequency and a tiny
// calculator.
//
//   Apps.search("fire")      ranked array of DesktopEntry objects
//   Apps.launch(entry)       count it, run it, close the overlay
//   Apps.calc("2+2*2")       { ok, value, text }
//
// Apps come from DesktopEntries.applications, which fills in about a second
// after startup (it is empty at first; `all` updates when it fills).
Singleton {
	id: root

	// Launchable entries sorted by name.
	readonly property var all: {
		var list = DesktopEntries.applications.values.filter(e => !e.noDisplay);
		list.sort((a, b) => a.name.localeCompare(b.name));
		return list;
	}
	readonly property var counts: Settings.state.launchCounts || ({})

	// Lower-cased searchable fields per entry, rebuilt when `all` changes.
	readonly property var index: all.map(e => ({
		entry: e,
		name: e.name.toLowerCase(),
		generic: e.genericName.toLowerCase(),
		extra: (e.keywords.join(" ") + " " + e.comment).toLowerCase()
	}))

	function count(entry) { return counts[entry.id] || 0; }

	// 0 name prefix, 1 word prefix in name, 2 substring in name, 3 fuzzy name,
	// 4 generic name / keywords / comment, -1 no match.
	function tier(it, q) {
		var p = it.name.indexOf(q);
		if (p === 0) return 0;
		if (p > 0) {
			var w = it.name.search(new RegExp("[\\s\\-_.]" + q.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
			return w >= 0 ? 1 : 2;
		}
		var j = 0;
		for (var i = 0; i < it.name.length && j < q.length; i++) if (it.name[i] === q[j]) j++;
		if (j === q.length) return 3;
		if (it.generic.indexOf(q) >= 0 || it.extra.indexOf(q) >= 0) return 4;
		return -1;
	}

	function search(query) {
		var q = (query || "").trim().toLowerCase();
		var rows = [];
		for (var i = 0; i < index.length; i++) {
			var t = q === "" ? 0 : tier(index[i], q);
			if (t >= 0) rows.push({ e: index[i].entry, t: t, c: count(index[i].entry) });
		}
		rows.sort((a, b) => a.t - b.t || b.c - a.c || a.e.name.localeCompare(b.e.name));
		return rows.map(r => r.e);
	}

	function launch(entry) {
		var n = Object.assign({}, counts);
		n[entry.id] = (n[entry.id] || 0) + 1;
		Settings.setState("launchCounts", n);
		if (entry.runInTerminal) Quickshell.execDetached([Settings.opt("terminal", "alacritty"), "-e"].concat(entry.command));
		else entry.execute();
		Ui.close();
	}

	// ---- calculator (recursive descent, no eval) ----
	readonly property var constants: ({ pi: Math.PI, e: Math.E })
	readonly property var functions: ({
		sqrt: Math.sqrt, sin: Math.sin, cos: Math.cos, tan: Math.tan,
		asin: Math.asin, acos: Math.acos, atan: Math.atan,
		ln: Math.log, log: Math.log10, log2: Math.log2,
		abs: Math.abs, floor: Math.floor, ceil: Math.ceil, round: Math.round,
		min: Math.min, max: Math.max
	})

	function fmt(v) {
		if (v === 0) return "0";
		var s = parseFloat(v.toPrecision(10));
		return String(s);
	}

	function calc(expr) {
		var src = String(expr || "").trim().replace(/^=/, "").trim();
		var pos = 0;
		function fail(m) { throw new Error(m); }
		function ws() { while (pos < src.length && src[pos] === " ") pos++; }
		function eat(c) { ws(); if (src[pos] === c) { pos++; return true; } return false; }

		function parseExpr() {
			var v = parseTerm();
			for (;;) {
				if (eat("+")) v += parseTerm();
				else if (eat("-")) v -= parseTerm();
				else return v;
			}
		}
		function parseTerm() {
			var v = parseUnary();
			for (;;) {
				if (eat("*")) v *= parseUnary();
				else if (eat("/")) v /= parseUnary();
				else if (eat("%")) v %= parseUnary();
				else return v;
			}
		}
		function parseUnary() {
			if (eat("-")) return -parseUnary();
			if (eat("+")) return parseUnary();
			var b = parseAtom();
			return eat("^") ? Math.pow(b, parseUnary()) : b;
		}
		function parseAtom() {
			ws();
			var m = /^(\d+\.?\d*|\.\d+)(e[+-]?\d+)?/i.exec(src.slice(pos));
			if (m) { pos += m[0].length; return parseFloat(m[0]); }
			m = /^[a-z][a-z0-9]*/i.exec(src.slice(pos));
			if (m) {
				var id = m[0].toLowerCase();
				pos += m[0].length;
				if (eat("(")) {
					var f = root.functions[id];
					if (!f) fail("unknown function " + id);
					var args = [];
					if (!eat(")")) {
						do args.push(parseExpr()); while (eat(","));
						if (!eat(")")) fail("expected )");
					}
					if (args.length === 0) fail("no arguments");
					return f.apply(null, args);
				}
				if (root.constants[id] === undefined) fail("unknown name " + id);
				return root.constants[id];
			}
			if (eat("(")) {
				var v = parseExpr();
				if (!eat(")")) fail("expected )");
				return v;
			}
			return fail("unexpected input");
		}

		try {
			if (src === "") return { ok: false, value: NaN, text: "" };
			var r = parseExpr();
			ws();
			if (pos < src.length) fail("trailing input");
			if (typeof r !== "number" || !isFinite(r)) return { ok: false, value: NaN, text: "" };
			return { ok: true, value: r, text: fmt(r) };
		} catch (e) {
			return { ok: false, value: NaN, text: "" };
		}
	}
}
