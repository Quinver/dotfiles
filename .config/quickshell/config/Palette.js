.pragma library
// Colour science for the shell: OKLCH conversions, seed picking and palette generation.
// Everything takes/returns "#rrggbb" strings.

function _lin(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
function _gam(c) { return c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(c, 1 / 2.4) - 0.055; }

function parse(hex) {
	var h = String(hex).replace("#", "");
	if (h.length === 8) h = h.substring(2); // QML #aarrggbb
	if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
	var n = parseInt(h, 16);
	if (isNaN(n)) n = 0x808080;
	return [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255];
}

function toOklch(hex) {
	var c = parse(hex);
	var r = _lin(c[0]), g = _lin(c[1]), b = _lin(c[2]);
	var l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
	var m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
	var s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
	var L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
	var A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
	var B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
	var h = Math.atan2(B, A) * 180 / Math.PI;
	if (h < 0) h += 360;
	return { l: L, c: Math.sqrt(A * A + B * B), h: h };
}

function _rgb(L, C, h) {
	var a = C * Math.cos(h * Math.PI / 180), b = C * Math.sin(h * Math.PI / 180);
	var l = Math.pow(L + 0.3963377774 * a + 0.2158037573 * b, 3);
	var m = Math.pow(L - 0.1055613458 * a - 0.0638541728 * b, 3);
	var s = Math.pow(L - 0.0894841775 * a - 1.2914855480 * b, 3);
	return [
		4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
		-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
		-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
	];
}

// OKLCH -> "#rrggbb", reducing chroma until the colour fits in sRGB.
function hex(L, C, h) {
	L = Math.max(0, Math.min(1, L));
	var rgb = _rgb(L, C, h);
	for (var i = 0; i < 40; i++) {
		if (rgb[0] >= -0.0005 && rgb[0] <= 1.0005 && rgb[1] >= -0.0005 && rgb[1] <= 1.0005 && rgb[2] >= -0.0005 && rgb[2] <= 1.0005) break;
		C *= 0.92;
		rgb = _rgb(L, C, h);
	}
	var out = "#";
	for (var k = 0; k < 3; k++) {
		var v = Math.round(Math.max(0, Math.min(1, _gam(Math.max(0, rgb[k])))) * 255);
		out += (v < 16 ? "0" : "") + v.toString(16);
	}
	return out;
}

// Pick the most "characteristic" colour out of a quantizer result:
// colourful, not too dark, not blown out.
function pickSeed(list) {
	var best = null, bestScore = -1;
	for (var i = 0; i < list.length; i++) {
		var o = toOklch(list[i]);
		var lightFit = 1 - Math.min(1, Math.abs(o.l - 0.62) / 0.5);
		var score = o.c * (0.35 + 0.65 * lightFit);
		if (score > bestScore) { bestScore = score; best = list[i]; }
	}
	return best || "#7a8a99";
}

// opts: { mode: "dark"|"light", mono: bool, chroma: number, overrides: {role: hex} }
function generate(seed, opts) {
	opts = opts || {};
	var s = toOklch(seed || "#7a8a99");
	var light = opts.mode === "light";
	var mono = !!opts.mono;
	var k = mono ? 0 : (opts.chroma === undefined ? 1 : opts.chroma);
	var h = s.h;
	var accentC = Math.max(0.07, Math.min(0.15, s.c * 1.25)) * k;
	var tint = Math.min(0.018, 0.006 + s.c * 0.08) * k;   // neutral surfaces carry a hint of the hue
	function t(d, l) { return light ? l : d; }             // tone for dark / light mode
	var p = {
		bg:         hex(t(0.185, 0.975), tint, h),
		surface:    hex(t(0.225, 0.945), tint * 1.2, h),
		surfaceHi:  hex(t(0.270, 0.905), tint * 1.4, h),
		surfaceTop: hex(t(0.325, 0.860), tint * 1.6, h),
		outline:    hex(t(0.420, 0.760), tint * 1.8, h),
		outlineDim: hex(t(0.310, 0.860), tint * 1.5, h),
		fg:         hex(t(0.940, 0.200), tint * 0.6, h),
		fgDim:      hex(t(0.780, 0.380), tint * 1.2, h),
		fgMuted:    hex(t(0.600, 0.540), tint * 1.4, h),
		primary:    hex(t(0.800, 0.480), accentC, h),
		onPrimary:  hex(t(0.180, 0.985), accentC * 0.35, h),
		primaryDim: hex(t(0.360, 0.860), accentC * 0.55, h),
		secondary:  hex(t(0.790, 0.500), accentC * 0.45, h),
		tertiary:   hex(t(0.800, 0.500), accentC * 0.8, (h + 60) % 360),
		error:      hex(t(0.720, 0.540), mono ? 0.07 : 0.17, 25),
		warn:       hex(t(0.830, 0.620), mono ? 0.05 : 0.14, 80),
		ok:         hex(t(0.800, 0.560), mono ? 0.05 : 0.14, 150),
		shadow:     "#000000"
	};
	if (mono) {
		p.primary = hex(t(0.930, 0.180), 0, 0);
		p.onPrimary = hex(t(0.160, 0.980), 0, 0);
		p.primaryDim = hex(t(0.380, 0.820), 0, 0);
		p.secondary = hex(t(0.760, 0.400), 0, 0);
		p.tertiary = hex(t(0.660, 0.500), 0, 0);
	}
	var ov = opts.overrides || {};
	for (var key in ov) if (p[key] !== undefined) p[key] = ov[key];
	p.seed = seed;
	p.mode = light ? "light" : "dark";
	return p;
}

// 16 terminal colours that sit in the same lightness band as the UI palette.
function ansi(p, mono) {
	var light = p.mode === "light";
	var hues = [25, 145, 95, 255, 320, 200];
	var c = mono ? 0.035 : 0.12;
	var normal = [p.surfaceHi], bright = [p.outline];
	for (var i = 0; i < hues.length; i++) {
		normal.push(hex(light ? 0.50 : 0.74, c, hues[i]));
		bright.push(hex(light ? 0.42 : 0.84, c * 1.1, hues[i]));
	}
	normal.push(p.fgDim);
	bright.push(p.fg);
	return { normal: normal, bright: bright };
}

function alpha(hexColor, a) {
	var v = Math.round(Math.max(0, Math.min(1, a)) * 255);
	return "#" + (v < 16 ? "0" : "") + v.toString(16) + String(hexColor).replace("#", "");
}

// Linear blend of two "#rrggbb" colours, t in 0..1.
function mix(a, b, t) {
	if (t >= 1 || a === b) return b;
	if (t <= 0) return a;
	var x = parse(a), y = parse(b), out = "#";
	for (var i = 0; i < 3; i++) {
		var v = Math.round((x[i] + (y[i] - x[i]) * t) * 255);
		out += (v < 16 ? "0" : "") + v.toString(16);
	}
	return out;
}
