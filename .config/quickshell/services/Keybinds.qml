pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Live parse of the Hyprland Lua keybinds file (read-only).
//
//   Keybinds.binds     [{ section, mods: [..], key, desc, alias }] in file order (REPLACED on reload)
//   Keybinds.sections  [{ name, binds: [..] }] in file order, empty sections omitted
//   Keybinds.parse(text)  the parser, usable on any text
//
// mods/key are display-ready ("SUPER", "SHIFT", "Return"). alias is false for
// bindSuper(..., false) binds, which are not registered under Ctrl+Alt.
// Understands bindSuper(...), hl.bind(...), `-- ── Section ──` headers and the
// workspace `for` loops (each becomes one synthesized entry). Comments are skipped.
Singleton {
	id: root

	readonly property string path: Quickshell.env("HOME") + "/.config/hypr/UserConfigs/keybinds.lua"
	property var binds: []
	readonly property var sections: group(binds)

	FileView {
		path: root.path
		watchChanges: true
		onFileChanged: reload()
		onLoaded: root.binds = root.parse(text())
	}

	function group(list) {
		var out = [], byName = {};
		for (var i = 0; i < list.length; i++) {
			var b = list[i];
			if (!byName[b.section]) { byName[b.section] = { name: b.section, binds: [] }; out.push(byName[b.section]); }
			byName[b.section].binds.push(b);
		}
		return out;
	}

	// ---- parser ---------------------------------------------------------

	// Strip a trailing `-- comment` (outside strings); returns [code, comment].
	function splitComment(line) {
		var i = 0, n = line.length;
		while (i < n) {
			var c = line[i];
			if (c === "-" && line[i + 1] === "-") return [line.slice(0, i), line.slice(i + 2).trim()];
			if (c === "[" && line[i + 1] === "[") {
				var e = line.indexOf("]]", i + 2);
				i = e < 0 ? n : e + 2;
			} else if (c === '"' || c === "'") {
				i++;
				while (i < n && line[i] !== c) { if (line[i] === "\\") i++; i++; }
				i++;
			} else i++;
		}
		return [line, ""];
	}

	// Net paren depth change of a code line, ignoring strings.
	function depthDelta(code) {
		var d = 0, i = 0, n = code.length;
		while (i < n) {
			var c = code[i];
			if (c === "[" && code[i + 1] === "[") {
				var e = code.indexOf("]]", i + 2);
				i = e < 0 ? n : e + 2;
			} else if (c === '"' || c === "'") {
				i++;
				while (i < n && code[i] !== c) { if (code[i] === "\\") i++; i++; }
				i++;
			} else {
				if (c === "(" || c === "{") d++;
				else if (c === ")" || c === "}") d--;
				i++;
			}
		}
		return d;
	}

	// Split `a, f(b, c), {d, e}` on top-level commas.
	function splitArgs(s) {
		var out = [], cur = "", d = 0, i = 0, n = s.length;
		while (i < n) {
			var c = s[i];
			if (c === "[" && s[i + 1] === "[") {
				var e = s.indexOf("]]", i + 2);
				e = e < 0 ? n : e + 2;
				cur += s.slice(i, e); i = e; continue;
			}
			if (c === '"' || c === "'") {
				var j = i + 1;
				while (j < n && s[j] !== c) { if (s[j] === "\\") j++; j++; }
				cur += s.slice(i, j + 1); i = j + 1; continue;
			}
			if (c === "(" || c === "{") d++;
			else if (c === ")" || c === "}") d--;
			if (c === "," && d === 0) { out.push(cur.trim()); cur = ""; }
			else cur += c;
			i++;
		}
		if (cur.trim() !== "") out.push(cur.trim());
		return out;
	}

	function unquote(s) {
		var m = /^\[\[([\s\S]*)\]\]$/.exec(s) || /^"([\s\S]*)"$/.exec(s) || /^'([\s\S]*)'$/.exec(s);
		return m ? m[1] : null;
	}

	function trunc(s, n) { return s.length > n ? s.slice(0, n - 1) + "…" : s; }

	function prettyKey(k) {
		var map = { COMMA: ",", SPACE: "Space", RETURN: "Return", "mouse:272": "LMB", "mouse:273": "RMB" };
		if (map[k] !== undefined) return map[k];
		if (k.length === 1) return k.toUpperCase();
		if (/^XF86/.test(k)) return k.slice(4).replace(/([a-z])([A-Z])/g, "$1 $2");
		return k.charAt(0).toUpperCase() + k.slice(1).toLowerCase();
	}

	// camelCase / snake_case to lower-case words.
	function humanWords(s) { return s.replace(/([a-z])([A-Z])/g, "$1 $2").replace(/_/g, " ").toLowerCase(); }

	function humanExec(arg) {
		var s = unquote(arg);
		if (s === null) return "Run " + humanWords(trunc(arg, 24));
		var w = s.trim().split(/\s+/);
		var prog = w.shift().replace(/^.*\//, "");
		if ((prog === "sh" || prog === "bash" || prog === "env") && w.length) {
			while (w.length && /^-/.test(w[0])) w.shift();
			prog = (w.shift() || prog).replace(/^['"]/, "").replace(/^.*\//, "");
		}
		var tail = w.length && /^[A-Za-z][\w-]*$/.test(w[0]) ? " " + w[0] : "";
		return prog + tail;
	}

	// Description from a dispatcher / factory expression.
	function describe(expr) {
		expr = expr.trim();
		var m = /^function\s*\(\)\s*return\s+([\s\S]*?)\s+end$/.exec(expr);
		if (m) expr = m[1].trim();
		m = /^shell\("([^"]*)"\)$/.exec(expr);
		if (m) {
			var w = m[1].split(/\s+/);
			if (w[0] === "overlay" && w[1]) return "Open " + w[1];
			if (w[0] === "popout" && w[1]) return w[1] + " panel";
			return humanWords(m[1]);
		}
		m = /^hl\.dsp\.exec_cmd\(([\s\S]*)\)$/.exec(expr);
		if (m) return humanExec(m[1].trim());
		m = /^hl\.dsp\.([\w.]+)\(([\s\S]*)\)$/.exec(expr);
		if (m) {
			var name = m[1].replace(/[._]/g, " ");
			var vals = [], re = /(\w+)\s*=\s*"([^"]*)"|"([^"]*)"|workspace\s*=\s*(\d+)/g, v;
			while ((v = re.exec(m[2])) !== null) vals.push(v[4] ? "workspace " + v[4] : (v[2] !== undefined ? v[2] : v[3]));
			return trunc(name + (vals.length ? " " + vals.join(" ") : ""), 40);
		}
		m = /^(\w+)\("([^"]*)"\)$/.exec(expr);
		if (m) return trunc(humanWords(m[1]) + " " + humanWords(m[2]), 30);
		return trunc(expr, 40);
	}

	function parse(text) {
		var lines = text.split("\n"), out = [], section = "General";
		var i = 0;
		function push(mods, key, desc, alias) {
			out.push({ section: section, mods: mods, key: key, desc: desc, alias: alias });
		}
		while (i < lines.length) {
			var line = lines[i], t = line.trim();
			var hm = /^--\s*─+\s*(.+?)\s*─+\s*$/.exec(t);
			if (hm) { section = hm[1]; i++; continue; }
			if (t.indexOf("--") === 0) { i++; continue; }

			// workspace loops: classify by body
			if (/^for\s+\w+\s*=/.test(t)) {
				var body = "", j = i + 1;
				while (j < lines.length && lines[j].trim() !== "end") body += lines[j++] + "\n";
				if (/bindSuper\(\s*"SHIFT \+ "\s*\.\.\s*\w+/.test(body) && /window\.move/.test(body))
					push(["SUPER", "SHIFT"], "1–9", "Move window to workspace", true);
				else if (/bindSuper\(\s*\w+\s*,/.test(body) && /focus\(/.test(body))
					push(["SUPER"], "1–9", "Go to workspace", true);
				i = j + 1;
				continue;
			}

			var isSuper = /^bindSuper\(/.test(t);
			if (!isSuper && !/^hl\.bind\(/.test(t)) { i++; continue; }

			// join continuation lines until parentheses balance
			var code = "", comment = "", depth = 0;
			do {
				var sc = splitComment(lines[i]);
				code += sc[0] + " ";
				if (sc[1] !== "") comment = sc[1];
				depth += depthDelta(sc[0]);
				i++;
			} while (depth > 0 && i < lines.length);

			var inner = code.trim().replace(/^(bindSuper|hl\.bind)\(/, "").replace(/\)\s*$/, "");
			var args = splitArgs(inner);
			var combo = unquote(args[0] || "");
			if (combo === null || args.length < 2) continue;
			var parts = combo.split("+").map(s => s.trim()).filter(s => s !== "");
			var key = parts.pop();
			var mods = isSuper ? ["SUPER"].concat(parts) : parts;
			var desc = comment !== "" ? comment : describe(args[1]);
			push(mods, prettyKey(key), desc, !(isSuper && args[3] === "false"));
		}
		return out;
	}
}
