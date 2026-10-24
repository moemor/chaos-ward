// GDI+- und AHK-Nachbau auf Canvas 2D – genug, um den übersetzten Zeichen-Code der Treffer-Leiste laufen zu lassen.
"use strict";
// ---------------- AHK-Laufzeit ----------------
const A_ScriptDir = "";
const Cfg = { Lang: "de", Key: "F6", Theme: "obsidian" };
var Clr = { Gold: "D6A640", Gold2: "F0CF7A" };
Cfg.Accent = "gold"; Cfg.Mode = 3; Cfg.OvAlpha = 100;
let Dv = { Any: 0, Lines: [], Rules: new Map(), Item: "" };
let STR = {};
function T(k) { return STR[k] ?? k; }
function AMap(...a) { const m = new Map(); for (let i = 0; i + 1 < a.length; i += 2) m.set(a[i], a[i + 1]); return m; }
function R(get, set) { return { get, set, isRef: true }; }
class AHKMatch { constructor(m, off) { this.m = m; this.Pos = off + 1; this.Len = m[0].length; } }
function IDX(o, k) {
  if (o instanceof AHKMatch) return o.m[k] ?? "";
  if (Array.isArray(o)) { if (!(k >= 1 && k <= o.length)) throw new Error("Invalid index " + k + " (Länge " + o.length + ")"); return o[k - 1]; }
  if (o instanceof Map) { if (!o.has(k)) throw new Error("Map ohne Schlüssel " + k); return o.get(k); }
  if (typeof o === "string") return o[k - 1];
  return o[k];
}
function SETIDX(o, k, v) { if (Array.isArray(o)) o[k - 1] = v; else if (o instanceof Map) o.set(k, v); else o[k] = v; return v; }
function* AHK_FOR(x, n) {
  let i = 0;
  if (Array.isArray(x)) { for (const v of x) { i++; yield n === 1 ? [i, v] : [i, i, v]; } return; }
  if (x instanceof Map) { for (const [k, v] of x) { i++; yield n === 1 ? [i, k] : [i, k, v]; } return; }
  throw new Error("for über " + typeof x);
}
function* AHK_PARSE(s) { let i = 0; for (const c of String(s)) yield [++i, c]; }
Object.defineProperty(Array.prototype, "Length", { get() { return this.length; } });
Array.prototype.Push = function (...a) { this.push(...a); };
Array.prototype.Clone = function () { return this.slice(); };
Array.prototype.Has = function (i) { return i >= 1 && i <= this.length; };
Object.defineProperty(Map.prototype, "Count", { get() { return this.size; } });
Map.prototype.Has = function (k) { return this.has(k); };
Object.prototype.HasOwnProp = function (k) { return Object.prototype.hasOwnProperty.call(this, k); };
const Min = (...a) => Math.min(...a.map(Number)), Max = (...a) => Math.max(...a.map(Number));
const Round = (x, n = 0) => { const f = 10 ** n, v = Math.sign(x) * Math.round(Math.abs(x) * f) / f; return v; };
const Ceil = Math.ceil, Floor = Math.floor, Abs = Math.abs, Sin = Math.sin, Cos = Math.cos, Exp = Math.exp;
const Mod = (a, b) => a % b;
const Integer = x => Math.trunc(Number(x));
const IsDigit = s => /^\d*$/.test(String(s));
const IsNumber = v => typeof v === "number" || (/^\s*[+-]?(\d+\.?\d*|\.\d+)\s*$/.test(String(v)));
const IsObject = v => typeof v === "object" && v !== null;
const StrLen = s => String(s).length;
const SubStr = (s, p, n) => { s = String(s); const st = p > 0 ? p - 1 : Math.max(0, s.length + p); return n === undefined ? s.slice(st) : s.slice(st, st + n); };
const Trim = s => String(s).trim();
const RTrim = (s, ch = " \t") => { s = String(s); while (s && ch.includes(s[s.length - 1])) s = s.slice(0, -1); return s; };
const StrReplace = (s, a, b = "") => String(s).split(a).join(b);
function ahkRe(p, g) {
  let fl = g ? "g" : "";
  const m = /^([imsxADJUXPSC]*)\)/.exec(p);
  if (m) { if (m[1].includes("i")) fl += "i"; if (m[1].includes("m")) fl += "m"; p = p.slice(m[0].length); }
  p = p.replace(/\\x\{([0-9A-Fa-f]+)\}/g, "\\u{$1}");
  return new RegExp(p, fl + "u");
}
const RegExReplace = (s, p, r = "") => String(s).replace(ahkRe(p, true), r);
function RegExMatch(s, p, ref, pos = 1) {
  const re = ahkRe(p, true); re.lastIndex = pos - 1; const m = re.exec(String(s));
  if (!m) { if (ref) ref.set(""); return 0; }
  if (ref) ref.set(new AHKMatch(m, m.index)); return m.index + 1;
}
function Format(f, v) {
  return f.replace(/\{:(0?)(\d*)(?:\.(\d+))?f?\}/, (a, z, w, d) => { let s = d !== undefined ? Number(v).toFixed(+d) : String(Math.trunc(v)); if (w) s = s.padStart(+w, z ? "0" : " "); return s; });
}
// Buffer / NumPut / NumGet
const TSZ = { Float: 4, UInt: 4, Int: 4, UChar: 1, Char: 1, UShort: 2, Short: 2, Ptr: 8, Int64: 8, Double: 8, UPtr: 8 };
class Buf { constructor(n) { this.Size = n; this.v = new Map(); } }
const Buffer = n => new Buf(n);
function NumPut(...a) {
  let i = 0; const pairs = [];
  while (i + 1 < a.length && typeof a[i] === "string" && TSZ[a[i]] && !(a[i + 1] instanceof Buf)) { pairs.push([a[i], a[i + 1]]); i += 2; }
  const buf = a[i], off0 = a[i + 1] || 0; let off = off0;
  for (const [t, v] of pairs) { buf.v.set(off, Number(v)); off += TSZ[t]; }
  return off;
}
const NumGet = (buf, off, t) => buf.v.get(off) ?? 0;
const F = (buf, i) => buf.v.get(i * 4) ?? 0;          // i-te 4-Byte-Zahl
const FileExist = () => "A";

// ---------------- GDI+ ----------------
const IMAGES = {};        // Dateiname -> Image (vom Testgerüst vorgeladen)
let TITLES = null;        // (alt) vorberechnete Titel-Umrisse
const FAMS = { Body: { name: "Overpass", w: 400, asc: 1950, desc: 600, upm: 2000 }, Semi: { name: "Overpass", w: 600, asc: 1950, desc: 600, upm: 2000 },
  Cond: { name: "Overpass", w: 600, asc: 1950, desc: 600, upm: 2000 }, Mono: { name: "Overpass", w: 600, asc: 1950, desc: 600, upm: 2000 } };
function rgba(argb) { argb = argb >>> 0; const a = (argb >>> 24) / 255, r = (argb >> 16) & 255, g = (argb >> 8) & 255, b = argb & 255; return `rgba(${r},${g},${b},${a})`; }
class GPath { constructor() { this.ops = []; } }
function path2d(p) {
  const P = new Path2D();
  for (const o of p.ops) {
    if (o[0] === "arc") { const [, x, y, w, h, s, sw] = o; P.ellipse(x + w / 2, y + h / 2, w / 2, h / 2, 0, s * Math.PI / 180, (s + sw) * Math.PI / 180, sw < 0); }
    else if (o[0] === "ell") { const [, x, y, w, h] = o; P.moveTo(x + w, y + h / 2); P.ellipse(x + w / 2, y + h / 2, w / 2, h / 2, 0, 0, 2 * Math.PI); P.closePath(); }
    else if (o[0] === "close") P.closePath();
    else if (o[0] === "poly") { const pts = o[1]; pts.forEach(([x, y], i) => P[i ? "lineTo" : "moveTo"](x, y)); P.closePath(); }
    else if (o[0] === "text") { const t = textGeom(o); P.addPath(new Path2D(t.d), new DOMMatrix([t.s, 0, 0, -t.s, t.x, t.base])); }
  }
  return P;
}
function textGeom(o) {
  const [, str, fam, size, rect] = o, T0 = TITLES.texts[str];
  if (!T0) throw new Error("Titel nicht vorberechnet: " + str);
  const s = size / TITLES.upm, lineH = (TITLES.asc + TITLES.desc) * s;
  const base = rect[1] + (rect[3] - lineH) / 2 + TITLES.asc * s, x = rect[0] + size / 6;
  return { d: T0.d, s, x, base, xmin: x + T0.xmin * s, xmax: x + T0.xmax * s };
}
function fillStyleOf(ctx, br) {
  if (br.type === "solid") return rgba(br.argb);
  if (br.type === "linear") {
    const [x, y, w, h] = br.rect; const gr = br.mode === 1 ? ctx.createLinearGradient(x, y, x, y + h) : ctx.createLinearGradient(x, y, x + w, y);
    for (const [p, c] of br.stops) gr.addColorStop(p, rgba(c)); return gr;
  }
  throw new Error("Pinsel " + br.type);
}
const rectOf = b => [F(b, 0), F(b, 1), F(b, 2), F(b, 3)];
const GP = {
  GdipSaveGraphics(g, ref) { g.ctx.save(); ref.set(++g.n); },
  GdipRestoreGraphics(g, id) { g.ctx.restore(); },
  GdipTranslateWorldTransform(g, x, y) { g.ctx.translate(x, y); },
  GdipScaleWorldTransform(g, x, y) { g.ctx.scale(x, y); },
  GdipRotateWorldTransform(g, d) { g.ctx.rotate(d * Math.PI / 180); },
  GdipResetWorldTransform(g) { g.ctx.setTransform(1, 0, 0, 1, 0, 0); },
  GdipSetClipPath(g, p) { g.ctx.clip(path2d(p)); },
  GdipSetClipRect(g, x, y, w, h) { const P = new Path2D(); P.rect(x, y, w, h); g.ctx.clip(P); },
  GdipResetClip() {},
  GdipGraphicsClear(g) { const c = g.ctx; c.save(); c.setTransform(1, 0, 0, 1, 0, 0); c.clearRect(0, 0, c.canvas.width, c.canvas.height); c.restore(); },
  GdipSetSmoothingMode() {}, GdipSetTextRenderingHint() {}, GdipSetCompositingQuality() {}, GdipFlush() {},
  GdipSetInterpolationMode(g, m) { g.ctx.imageSmoothingQuality = m === 7 ? "high" : "medium"; },
  GdipCreatePath(mode, ref) { ref.set(new GPath()); },
  GdipAddPathArc(p, x, y, w, h, s, sw) { p.ops.push(["arc", x, y, w, h, s, sw]); },
  GdipAddPathEllipse(p, x, y, w, h) { p.ops.push(["ell", x, y, w, h]); p.ell = [x, y, w, h]; },
  GdipClosePathFigure(p) { p.ops.push(["close"]); },
  GdipAddPathPolygon(p, pts, n) { const a = []; for (let i = 0; i < n; i++) a.push([F(pts, 2 * i), F(pts, 2 * i + 1)]); p.ops.push(["poly", a]); },
  GdipSetPathFillMode(p, m) { p.fill = m; },
  GdipSetPenStartCap(pen, c) { pen.cap = c === 2 ? "round" : "butt"; }, GdipSetPenEndCap(pen, c) { pen.cap = c === 2 ? "round" : "butt"; },
  GdipDrawRectangle(g, pen, x, y, w, h) { const c = g.ctx; c.strokeStyle = rgba(pen.argb); c.lineWidth = pen.w; c.strokeRect(x, y, w, h); },
  GdipAddPathString(p, str, len, fam, style, size, rectBuf, fmt) { p.ops.push(["text", str, fam, size, rectOf(rectBuf)]); },
  GdipGetPathWorldBounds(p, rb) { const o = p.ops.find(x => x[0] === "text"); const t = textGeom(o); rb.v.set(0, t.xmin); rb.v.set(4, 0); rb.v.set(8, t.xmax - t.xmin); rb.v.set(12, o[3]); },
  GdipDeletePath() {}, GdipDeleteBrush() {}, GdipDeletePen() {}, GdipDeleteStringFormat() {}, GdipDeleteFont() {}, GdipDeleteGraphics() {},
  GdipCreateSolidFill(argb, ref) { ref.set({ type: "solid", argb }); },
  GdipCreateLineBrushFromRect(rb, c1, c2, mode, wrap, ref) { ref.set({ type: "linear", rect: rectOf(rb), mode, stops: [[0, c1], [1, c2]] }); },
  GdipSetLinePresetBlend(br, cols, pos, n) { br.stops = []; for (let i = 0; i < n; i++) br.stops.push([F(pos, i), F(cols, i)]); },
  GdipCreatePathGradientFromPath(p, ref) { ref.set({ type: "pathgrad", ell: p.ell, center: 0, surround: 0 }); },
  GdipSetPathGradientCenterColor(br, c) { br.center = c; },
  GdipSetPathGradientSurroundColorsWithCount(br, colBuf) { br.surround = F(colBuf, 0); },
  GdipSetPathGradientCenterPoint() {},
  GdipCreatePen1(argb, w, unit, ref) { ref.set({ argb, w, join: "miter" }); },
  GdipSetPenLineJoin(pen, j) { pen.join = j === 2 ? "round" : "miter"; },
  GdipFillPath(g, br, p) {
    const c = g.ctx;
    if (br.type === "pathgrad") {
      const [x, y, w, h] = br.ell; c.save(); c.translate(x + w / 2, y + h / 2); c.scale(w / 2, h / 2);
      const gr = c.createRadialGradient(0, 0, 0, 0, 0, 1); gr.addColorStop(0, rgba(br.center)); gr.addColorStop(1, rgba(br.surround));
      c.fillStyle = gr; c.beginPath(); c.arc(0, 0, 1, 0, 2 * Math.PI); c.fill(); c.restore(); return;
    }
    c.fillStyle = fillStyleOf(c, br); c.fill(path2d(p), p.fill === 1 ? "nonzero" : "evenodd");
  },
  GdipDrawPath(g, pen, p) { const c = g.ctx; c.strokeStyle = rgba(pen.argb); c.lineWidth = pen.w; c.lineJoin = pen.join; c.stroke(path2d(p)); },
  GdipFillEllipse(g, br, x, y, w, h) { const c = g.ctx; c.fillStyle = fillStyleOf(c, br); c.beginPath(); c.ellipse(x + w / 2, y + h / 2, Math.abs(w / 2), Math.abs(h / 2), 0, 0, 2 * Math.PI); c.fill(); },
  GdipDrawEllipse(g, pen, x, y, w, h) { const c = g.ctx; c.strokeStyle = rgba(pen.argb); c.lineWidth = pen.w; c.beginPath(); c.ellipse(x + w / 2, y + h / 2, Math.abs(w / 2), Math.abs(h / 2), 0, 0, 2 * Math.PI); c.stroke(); },
  GdipFillRectangle(g, br, x, y, w, h) { const c = g.ctx; c.fillStyle = fillStyleOf(c, br); c.fillRect(x, y, w, h); },
  GdipFillPolygon(g, br, pts, n) { const c = g.ctx; c.fillStyle = fillStyleOf(c, br); c.beginPath(); for (let i = 0; i < n; i++) c[i ? "lineTo" : "moveTo"](F(pts, 2 * i), F(pts, 2 * i + 1)); c.closePath(); c.fill(); },
  GdipDrawLine(g, pen, x1, y1, x2, y2) { const c = g.ctx; c.strokeStyle = rgba(pen.argb); c.lineWidth = pen.w; c.lineCap = pen.cap || "butt"; c.beginPath(); c.moveTo(x1, y1); c.lineTo(x2, y2); c.stroke(); },
  GdipDrawLines(g, pen, pts, n) { const c = g.ctx; c.strokeStyle = rgba(pen.argb); c.lineWidth = pen.w; c.lineJoin = pen.join; c.beginPath(); for (let i = 0; i < n; i++) c[i ? "lineTo" : "moveTo"](F(pts, 2 * i), F(pts, 2 * i + 1)); c.stroke(); },
  GdipLoadImageFromFile(f, ref) { const n = f.split("\\").pop(); ref.set(IMAGES[n] || 0); },
  GdipGetImageWidth(im, ref) { ref.set(im.width); }, GdipGetImageHeight(im, ref) { ref.set(im.height); },
  GdipDrawImageRectI(g, im, x, y, w, h) { g.ctx.drawImage(im, x, y, w, h); },
  GdipCreateImageAttributes(ref) { ref.set({}); },
  GdipSetImageAttributesColorMatrix(at, t, en, cm) { at.tint = [cm.v.get(0), cm.v.get(24), cm.v.get(48)]; at.alpha = cm.v.get(72); },
  GdipDrawImageRectRect(g, im, dx, dy, dw, dh, sx, sy, sw, sh, unit, at) {
    const key = at.tint.map(v => v.toFixed(3)).join(","); im.__t = im.__t || {};
    if (!im.__t[key]) { const cv = document.createElement("canvas"); cv.width = im.width; cv.height = im.height; const x = cv.getContext("2d");
      x.drawImage(im, 0, 0); const d = x.getImageData(0, 0, cv.width, cv.height); for (let i = 0; i < d.data.length; i += 4) { d.data[i] *= at.tint[0]; d.data[i + 1] *= at.tint[1]; d.data[i + 2] *= at.tint[2]; }
      x.putImageData(d, 0, 0); im.__t[key] = cv; }
    const c = g.ctx; c.save(); c.globalAlpha = Math.max(0, Math.min(1, at.alpha)); c.drawImage(im.__t[key], sx, sy, sw, sh, dx, dy, dw, dh); c.restore();
  },
  GdipDrawImageRect(g, im, x, y, w, h) { g.ctx.drawImage(im, x, y, w, h); },
  GdipDisposeImageAttributes() {},
  GdipCreateBitmapFromScan0() { throw new Error("nicht nachgebaut"); },
  GdipCreateFont(fam, size, style, unit, ref) { ref.set({ fam, size, weight: style & 1 ? 700 : fam.w }); },
  GdipCreateStringFormat(flags, lang, ref) { ref.set({ flags, align: 0, line: 0, trim: 0 }); },
  GdipSetStringFormatAlign(f, a) { f.align = a; }, GdipSetStringFormatLineAlign(f, a) { f.line = a; }, GdipSetStringFormatTrimming(f, t) { f.trim = t; },
  GdipMeasureString(g, str, len, font, rb, fmt, box) {
    const c = g.ctx; c.font = `${font.weight} ${font.size}px "${font.fam.name}"`;
    box.v.set(8, c.measureText(String(str)).width + font.size / 3);
  },
  GdipDrawString(g, str, len, font, rb, fmt, br) {
    const c = g.ctx, [x, y, w, h] = rectOf(rb), fm = font.fam, sz = font.size, pad = sz / 6;
    c.font = `${font.weight} ${sz}px "${fm.name}"`; c.fillStyle = fillStyleOf(c, br);
    let s = String(str); const avail = w - 2 * pad;
    if (fmt.trim === 3 && c.measureText(s).width > avail) { while (s.length > 1 && c.measureText(s + "…").width > avail) s = s.slice(0, -1); s += "…"; }
    const lineH = (fm.asc + fm.desc) / fm.upm * sz, base = (fmt.line === 1 ? y + (h - lineH) / 2 : y) + fm.asc / fm.upm * sz;
    c.textBaseline = "alphabetic"; c.textAlign = fmt.align === 1 ? "center" : fmt.align === 2 ? "right" : "left";
    c.fillText(s, fmt.align === 1 ? x + w / 2 : fmt.align === 2 ? x + w - pad : x + pad, base);
  },
};
function DllCall(name, ...a) {
  const fn = name.split("\\").pop(); const vals = [];
  for (let i = 0; i + 1 < a.length; i += 2) vals.push(a[i + 1]);
  if (!GP[fn]) throw new Error("DllCall fehlt: " + fn);
  return GP[fn](...vals) || 0;
}
// handgeschrieben (in AHK mit try/Dateien): Schriftfamilien
const HitBmps = new Map();
let HitBarPos = { S: 1.5 };
function HitCacheNew(key, w, h, ref) { const cv = document.createElement("canvas"); cv.width = w; cv.height = h; const g2 = { ctx: cv.getContext("2d"), n: 0 }; ref.set(g2); HitBmps.set(key, cv); cv.toString = () => "bmp:" + key; return cv; }
function HitFonts() { return { Body: FAMS.Body, Semi: FAMS.Semi, Cond: FAMS.Cond, Mono: FAMS.Mono }; }
function FontFamily() { return FAMS.Body; }
