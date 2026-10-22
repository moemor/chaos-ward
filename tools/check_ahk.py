"""Statische Prüfung für ChaosWard.ahk: lokale Variablen, die (ohne Groß/Klein) wie aufgerufene Funktionen heißen."""
import re, sys
src = open(sys.argv[1], encoding='utf-8-sig').read()
code = re.sub(r'"(?:[^"`\n]|`.)*"', '""', src)
code = re.sub(r"'(?:[^'`\n]|`.)*'", "''", code)
code = re.sub(r'(?m)(^|\s);.*$', r'\1', code)
lines = code.split('\n')
funcs = {}
hdr = re.compile(r'^([A-Za-z_]\w*)\(([^)]*)\)\s*(\{|=>)')
i = 0; problems = []
allfuncs = set()
for l in lines:
    m = hdr.match(l)
    if m: allfuncs.add(m.group(1).lower())
BUILTIN_FUNCS = {x.lower() for x in 'Round Sin Cos Min Max Mod Abs Integer Float String Buffer NumPut NumGet DllCall FileExist StrLen SubStr InStr StrReplace StrSplit RegExMatch RegExReplace Trim Format IsObject IsNumber IsInteger Map Gui SetTimer Sleep MsgBox Run IniRead IniWrite FileOpen DirCreate FormatTime MouseGetPos Chr Ord StrLower StrUpper Floor Ceil Sqrt Exp Log Ln Type HasProp Random'.split()}
callable_names = allfuncs | BUILTIN_FUNCS
while i < len(lines):
    m = hdr.match(lines[i])
    if not m:
        i += 1; continue
    name, params = m.group(1), m.group(2)
    start = i
    if m.group(3) == '=>':
        body = [lines[i].split('=>', 1)[1]]; i += 1
    else:
        depth = lines[i].count('{') - lines[i].count('}'); body = [lines[i][m.end():]]; i += 1
        while i < len(lines) and depth > 0:
            depth += lines[i].count('{') - lines[i].count('}'); body.append(lines[i]); i += 1
    text = '\n'.join(body)
    glob = set()
    for g in re.findall(r'(?m)^\s*global\s+(.*)$', text):
        for part in g.split(','):
            w = re.match(r'\s*([A-Za-z_]\w*)', part)
            if w: glob.add(w.group(1).lower())
    locs = set()
    for p in params.split(','):
        w = re.match(r'\s*&?([A-Za-z_]\w*)', p)
        if w: locs.add(w.group(1).lower())
    for v in re.findall(r'(?<![.\w])([A-Za-z_]\w*)\s*(?::=|\+=|-=|\*=|/=|\.=)', text): locs.add(v.lower())
    for v in re.findall(r'&([A-Za-z_]\w*)', text): locs.add(v.lower())
    for a, b in re.findall(r'(?m)\bfor\s+([A-Za-z_]\w*)(?:\s*,\s*([A-Za-z_]\w*))?\s+in\b', text):
        locs.add(a.lower()); b and locs.add(b.lower())
    for v in re.findall(r'\bcatch\s+(?:\w+\s+)?as\s+(\w+)', text): locs.add(v.lower())
    for v in re.findall(r'(?m)^\s*static\s+([A-Za-z_]\w*)', text): locs.add(v.lower())
    locs -= glob
    calls = {c.lower() for c in re.findall(r'(?<![.\w])([A-Za-z_]\w*)\(', text)}
    bad = locs & calls & callable_names
    # Funktionsnamen als Variable überschreiben (auch ohne Aufruf in dieser Funktion) = gefährlich bei allen Funktionsnamen
    shadow = locs & allfuncs
    for b in sorted(bad | shadow):
        problems.append((start + 1, name, b, 'AUFRUF' if b in bad else 'verdeckt'))
for p in problems: print(*p)
print('Funktionen:', len(allfuncs), 'Probleme:', len(problems))

# --- 2) lokale Zuweisung verdeckt eine globale Variable (ohne 'global'-Zeile) -> Funktion liest dann leeren lokalen Wert
gl = set()
for l in lines:
    m = re.match(r'^global\s+(.*)$', l)
    if m:
        g = m.group(1)
        for _ in range(6):
            g = re.sub(r'\{[^{}]*\}|\[[^\[\]]*\]|\([^()]*\)', '0', g)
        g = re.sub(r'\{.*$', '0', g)
        for part in g.split(','):
            w = re.match(r'\s*([A-Za-z_]\w*)', part)
            if w: gl.add(w.group(1).lower())
i = 0; warn = []
while i < len(lines):
    m = hdr.match(lines[i])
    if not m: i += 1; continue
    name, params = m.group(1), m.group(2); start = i
    if m.group(3) == '=>':
        body = [lines[i].split('=>', 1)[1]]; i += 1
    else:
        depth = lines[i].count('{') - lines[i].count('}'); body = [lines[i][m.end():]]; i += 1
        while i < len(lines) and depth > 0:
            depth += lines[i].count('{') - lines[i].count('}'); body.append(lines[i]); i += 1
    text = '\n'.join(body)
    decl = set()
    for g in re.findall(r'(?m)^\s*global\s+(.*)$', text):
        for part in g.split(','):
            w = re.match(r'\s*([A-Za-z_]\w*)', part)
            if w: decl.add(w.group(1).lower())
    if re.search(r'(?m)^\s*global\s*$', text): continue
    assigned = {v.lower() for v in re.findall(r'(?<![.\w])([A-Za-z_]\w*)\s*(?::=|\+=|-=|\*=|/=|\.=|\+\+|--)', text)}
    assigned |= {v.lower() for v in re.findall(r'&([A-Za-z_]\w*)', text)}
    for a, b in re.findall(r'(?m)\bfor\s+([A-Za-z_]\w*)(?:\s*,\s*([A-Za-z_]\w*))?\s+in\b', text):
        assigned.add(a.lower()); b and assigned.add(b.lower())
    params_l = {re.match(r'\s*&?(\w*)', p).group(1).lower() for p in params.split(',')}
    for v in sorted((assigned | params_l) & gl - decl):
        warn.append((start + 1, name, v))
for w in warn: print('GLOBAL-VERDECKT', *w)
print('Globale:', len(gl), 'Warnungen:', len(warn))

# --- 3) Aufrufe eigener Funktionen mit falscher Anzahl Argumente
sig = {}
for l in lines:
    m = hdr.match(l)
    if not m: continue
    ps = [p.strip() for p in m.group(2).split(',')] if m.group(2).strip() else []
    var = any(p.endswith('*') for p in ps)
    req = sum(1 for p in ps if ':=' not in p and not p.endswith('*'))
    sig[m.group(1).lower()] = (req, 10**6 if var else len([p for p in ps if not p.endswith('*')]))
bad = 0
for ln, l in enumerate(lines, 1):
    if hdr.match(l): continue
    for m in re.finditer(r'(?<![.\w])([A-Za-z_]\w*)\(', l):
        n = m.group(1).lower()
        if n not in sig: continue
        j = m.end(); depth = 1; args = 0; nonempty = False
        while j < len(l) and depth:
            ch = l[j]
            if ch in '([{': depth += 1
            elif ch in ')]}': depth -= 1
            elif ch == ',' and depth == 1: args += 1
            if depth and not ch.isspace(): nonempty = True
            j += 1
        if depth: continue                        # mehrzeilig -> überspringen
        cnt = args + 1 if nonempty else 0
        if '*)' in l[m.end():j].replace(' ', ''): continue
        lo, hi = sig[n]
        if not (lo <= cnt <= hi):
            bad += 1; print('ARGUMENTE', ln, m.group(1), cnt, 'erwartet', lo, '-', hi)
print('Argument-Fehler:', bad)

# --- 4) gleicher Name in verschiedener Schreibweise (AHK ignoriert Groß/Klein!) -> eine Variable
def idents(t):
    t2 = re.sub(r'(?<=\.)[A-Za-z_]\w*', '', t)              # Eigenschaften (.Name) ignorieren
    t2 = re.sub(r'\b\w+\s*:(?!=)', '', t2)                  # Objekt-Schlüssel {Name: ...} ignorieren
    return re.findall(r'(?<![\w.])([A-Za-z_]\w*)(?!\w)', t2)
i = 0; cs = 0
globals_exact = {}
for l in lines:
    m = re.match(r'^global\s+(.*)$', l)
    if m:
        g = m.group(1)
        for _ in range(6): g = re.sub(r'\{[^{}]*\}|\[[^\[\]]*\]|\([^()]*\)', '0', g)
        for part in re.sub(r'\{.*$', '0', g).split(','):
            w = re.match(r'\s*([A-Za-z_]\w*)', part)
            if w: globals_exact.setdefault(w.group(1).lower(), set()).add(w.group(1))
while i < len(lines):
    m = hdr.match(lines[i])
    if not m: i += 1; continue
    name, params = m.group(1), m.group(2); start = i
    if m.group(3) == '=>':
        body = [lines[i].split('=>', 1)[1]]; i += 1
    else:
        depth = lines[i].count('{') - lines[i].count('}'); body = [lines[i][m.end():]]; i += 1
        while i < len(lines) and depth > 0:
            depth += lines[i].count('{') - lines[i].count('}'); body.append(lines[i]); i += 1
    text = params + '\n' + '\n'.join(body)
    assigned = {v.lower() for v in re.findall(r'(?<![.\w])([A-Za-z_]\w*)\s*(?::=|\+=|-=|\*=|/=|\.=)', text)}
    assigned |= {v.lower() for v in re.findall(r'&([A-Za-z_]\w*)', text)}
    for a, b in re.findall(r'(?m)\bfor\s+([A-Za-z_]\w*)(?:\s*,\s*([A-Za-z_]\w*))?\s+in\b', text):
        assigned.add(a.lower()); b and assigned.add(b.lower())
    spell = {}
    for w in idents(text):
        if w.lower() in assigned: spell.setdefault(w.lower(), set()).add(w)
    for k, v in spell.items():
        if k in globals_exact: v = v | globals_exact[k]
        calls_fn = k in allfuncs
        if len(v) > 1 and not calls_fn:
            cs += 1; print('SCHREIBWEISE', start + 1, name, sorted(v))
print('Schreibweisen-Konflikte:', cs)

# --- 5) globale Zuweisungen NACH dem Ende des Auto-Execute-Bereichs (erstes 'return' ganz links) werden nie ausgeführt
late = 0; seen_return = False
for ln, l in enumerate(lines, 1):
    if re.match(r'^return\b', l): seen_return = True; continue
    if seen_return and re.match(r'^global\s+\w+\s*:=', l):
        late += 1; print('SPAET-GLOBAL', ln, l.strip()[:70])
print('Späte globale Zuweisungen:', late)

# --- 6) reservierte Eigenschaften: {Base: x} oder obj.Base := x ersetzt den Bauplan des Objekts -> "Invalid base"
res = 0
for ln, l in enumerate(lines, 1):
    for m in re.finditer(r'(?:[{,]\s*(base|__class|__item)\s*:(?!=))|(?:\.(base)\s*:=)', l, re.I):
        res += 1; print('RESERVIERT', ln, l.strip()[:80])
print('Reservierte Eigenschaften:', res)

# --- 7) einzeiliges try/catch/finally direkt vor "else": AutoHotkey ordnet das else dem try zu -> "Unexpected Else"
te = 0
for ln in range(len(lines) - 1):
    a, b = lines[ln], lines[ln + 1]
    if re.match(r'^\s*(try|catch|finally)\b(?!\s*\{)(?!\s*$)', a) and re.match(r'^\s*else\b', b):
        te += 1; print('TRY-ELSE', ln + 1, a.strip()[:60], '|', b.strip()[:30])
    if re.match(r'^\s*(if|else if|else)\b[^{]*$', a) and re.match(r'^\s*try\b(?!\s*\{)', b) and ln + 2 < len(lines) and re.match(r'^\s*else\b', lines[ln + 2]):
        te += 1; print('TRY-ELSE', ln + 2, b.strip()[:60], '|', lines[ln + 2].strip()[:30])
print('try/else-Fallen:', te)

# --- 8) doppelte Funktionen und doppelte case-Werte (Ladefehler)
from collections import Counter
fn = Counter(m.group(1).lower() for l in lines for m in [hdr.match(l)] if m)
dups = [k for k, v in fn.items() if v > 1]
for k in dups: print('DOPPELTE-FUNKTION', k)
cases_dup = 0
stack = []
for ln, l in enumerate(src.split('\n'), 1):
    if re.match(r'^\s*switch\b', l): stack.append((ln, set()))
    m = re.match(r'^\s*case\s+(.+?):\s*(;.*)?$', l)
    if m and stack:
        for v in re.findall(r'"[^"]*"|[^,\s]+', m.group(1)):
            if v in stack[-1][1]: cases_dup += 1; print('DOPPELTER-CASE', ln, v)
            stack[-1][1].add(v)
    if re.match(r'^\s*default\s*:', l) and stack: stack.pop()
print('Doppelte Funktionen:', len(dups), ' doppelte case:', cases_dup)
