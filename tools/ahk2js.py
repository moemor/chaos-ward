"""Kleiner AHK-v2 -> JavaScript-Übersetzer für die Zeichen-Funktionen der Treffer-Leiste.
Damit läuft der ECHTE Zeichen-Code (DrawHitScene & Co.) im Browser auf einem GDI+-Nachbau (gdip_shim.js)
und lässt sich als Video/Bild prüfen. Deckt nur die Sprachmittel ab, die diese Funktionen benutzen.

Aufruf: python3 ahk2js.py <script.ahk> <out.js> Func1 Func2 ...
"""
import re, sys

KEYW = {'if', 'else', 'while', 'loop', 'for', 'in', 'return', 'static', 'global', 'continue', 'break', 'and', 'or', 'not', 'is', 'try', 'catch'}
TOK = re.compile(r'''
   (?P<ws>[ \t]+)
 | (?P<str>"(?:[^"`]|`.)*")
 | (?P<num>0x[0-9A-Fa-f]+|\d+\.\d*|\.\d+|\d+)
 | (?P<id>[A-Za-z_][A-Za-z0-9_]*)
 | (?P<op>:=|\+=|-=|\*=|/=|\.=|\*\*|//|<<|>>|<=|>=|!=|==|&&|\|\||=>|[-+*/%<>=!&|^~?:.,()\[\]{}])
''', re.X)


def tokenize(s):
    out, i = [], 0
    while i < len(s):
        m = TOK.match(s, i)
        if not m:
            raise SyntaxError('cannot tokenize: ' + s[i:i + 40])
        kind = m.lastgroup
        out.append((kind, m.group()))
        i = m.end()
    return out


def conv_str(lit):
    body = lit[1:-1]
    res, i = '', 0
    while i < len(body):
        c = body[i]
        if c == '`' and i + 1 < len(body):
            n = body[i + 1]
            res += {'n': '\\n', 't': '\\t', 'r': '\\r', '"': '\\"', '`': '`', ';': ';'}.get(n, n)
            i += 2
            continue
        if c == '\\':
            res += '\\\\'
        else:
            res += c
        i += 1
    return '"' + res + '"'


def is_operand_end(t):
    k, v = t
    return k in ('str', 'num') or (k == 'id' and v not in KEYW) or v in (')', ']')


def is_operand_start(t):
    k, v = t
    return k in ('str', 'num') or (k == 'id' and v not in KEYW) or v in ('(',)


def expr(s):
    """eine AHK-Ausdruckszeile -> JS"""
    toks = tokenize(s)
    # 1) Tokens normalisieren, Leerzeichen merken (für implizites Verketten)
    seq = []
    for i, (k, v) in enumerate(toks):
        if k == 'ws':
            if seq:
                seq[-1] = (seq[-1][0], seq[-1][1], True)
            continue
        seq.append((k, v, False))
    out = []
    i = 0
    while i < len(seq):
        k, v, sp = seq[i]
        nxt = seq[i + 1] if i + 1 < len(seq) else None
        if k == 'str':
            out.append(conv_str(v))
        elif k == 'op' and v == ':=':
            out.append('=')
        elif k == 'op' and v == '=':
            out.append('==')
        elif k == 'op' and v == '.=':
            out.append('+= "" +')
        elif k == 'op' and v == '&' and nxt and nxt[0] == 'id' and (not [x for x in out if x.strip()] or [x for x in out if x.strip()][-1] in ('(', ',')):
            name = nxt[1]
            out.append(f'R(()=>{name},(__v)=>{name}=__v)')
            i += 2
            # Leerzeichen-Info des Namens übernehmen
            if nxt[2] and i < len(seq):
                pass
            continue
        elif k == 'id' and v == 'Map' and nxt and nxt[1] == '(':
            out.append('AMap')
        elif k == 'id' and v == 'and':
            out.append('&&')
        elif k == 'id' and v == 'or':
            out.append('||')
        elif k == 'id' and v == 'not':
            out.append('!')
        elif k == 'op' and v == '//':
            raise SyntaxError('// nicht unterstützt: ' + s)
        else:
            out.append(v)
        # implizites Verketten: Operand  Leerzeichen  Operand
        if sp and nxt and is_operand_end((k, v)) and is_operand_start(nxt[:2]):
            out.append(' + "" + ')
        elif sp:
            out.append(' ')
        i += 1
    return index_rewrite(''.join(out))


def str_mask(js):
    mask, ins, i = [False] * len(js), False, 0
    while i < len(js):
        if js[i] == '"':
            mask[i] = True
            ins = not ins
        elif ins:
            mask[i] = True
            if js[i] == '\\' and i + 1 < len(js):
                mask[i + 1] = True
                i += 1
        i += 1
    return mask


def index_rewrite(js):
    """A[B] -> IDX(A, B), A[B] = v -> SETIDX(A, B, v) (1-basierte Arrays und Maps wie in AHK)"""
    changed = True
    while changed:
        changed = False
        mask = str_mask(js)
        # innerste Indizierung zuerst: '[' ohne weiteres '[' bis zum passenden ']'
        for p in [i for i, c in enumerate(js) if c == '[' and not mask[i]]:
            j = p - 1
            while j >= 0 and js[j] == ' ':
                j -= 1
            if j < 0 or not (js[j].isalnum() or js[j] in '_)]'):
                continue          # Array-Literal
            # Ende der Klammer finden
            depth, q = 0, p
            while q < len(js):
                if mask[q]:
                    q += 1
                    continue
                if js[q] in '([{':
                    depth += 1
                elif js[q] in ')]}':
                    depth -= 1
                    if depth == 0:
                        break
                q += 1
            inner = js[p + 1:q]
            im = mask[p + 1:q]
            if any(c == '[' and not im[k] and k > 0 and re.match(r'[\w)\]]', inner[k - 1]) for k, c in enumerate(inner)):
                continue          # innere zuerst
            # Anfang des Ausdrucks davor
            a = j
            while a >= 0:
                if js[a] in ')]':
                    d, a2 = 0, a
                    while a2 >= 0:
                        if js[a2] in ')]':
                            d += 1
                        elif js[a2] in '([':
                            d -= 1
                            if d == 0:
                                break
                        a2 -= 1
                    a = a2 - 1
                    continue
                if js[a].isalnum() or js[a] in '_.$':
                    a -= 1
                    continue
                break
            base = js[a + 1:j + 1]
            rest = js[q + 1:]
            ma = re.match(r'\s*=(?!=)\s*(.*)$', rest)
            if ma:
                js = js[:a + 1] + f'SETIDX({base}, {inner}, {ma.group(1)})'
            else:
                js = js[:a + 1] + f'IDX({base}, {inner})' + rest
            changed = True
            break
    return js


def split_top_commas(s):
    parts, d, cur, ins = [], 0, '', False
    for c in s:
        if c == '"':
            ins = not ins
        if not ins:
            if c in '([{':
                d += 1
            elif c in ')]}':
                d -= 1
            elif c == ',' and d == 0:
                parts.append(cur)
                cur = ''
                continue
        cur += c
    parts.append(cur)
    return parts


def strip_comment(line):
    ins = False
    for i, c in enumerate(line):
        if c == '"' and (i == 0 or line[i - 1] != '`'):
            ins = not ins
        if c == ';' and not ins and (i == 0 or line[i - 1] in ' \t'):
            return line[:i].rstrip()
    return line.rstrip()


def get_funcs(src):
    """Name -> (params, Körper-Zeilen) ; auch Einzeiler 'F(x) => expr'"""
    lines = src.split('\n')
    funcs = {}
    i = 0
    while i < len(lines):
        ln = strip_comment(lines[i])
        m = re.match(r'^([A-Za-z_]\w*)\((.*?)\)\s*=>\s*(.+)$', ln)
        if m:
            funcs[m.group(1)] = (m.group(2), ['return ' + m.group(3)])
            i += 1
            continue
        m = re.match(r'^([A-Za-z_]\w*)\((.*)\)\s*\{\s*$', ln)
        if m:
            name, params = m.group(1), m.group(2)
            body, depth = [], 1
            i += 1
            while i < len(lines):
                l2 = strip_comment(lines[i])
                st = l2.strip()
                # Klammer-Tiefe nur über Zeilen-Anfang/Ende ('{' am Ende, '}' am Anfang)
                if st.startswith('}'):
                    depth -= 1
                if depth == 0:
                    break
                if st.endswith('{'):
                    depth += 1
                body.append(l2)
                i += 1
            funcs[name] = (params, body)
        i += 1
    return funcs


def conv_params(p):
    out = []
    for part in split_top_commas(p):
        part = part.strip()
        if not part:
            continue
        m = re.match(r'^&?(\w+)\s*(?::=\s*(.*))?$', part)
        out.append(m.group(1) + (' = ' + expr(m.group(2)) if m.group(2) else ''))
    return ', '.join(out)


def conv_func(name, params, body):
    # Fortsetzungszeilen (beginnen mit ',') an die vorige hängen
    joined = []
    for l in body:
        if l.strip().startswith(',') and joined:
            joined[-1] += ' ' + l.strip()
        elif l.strip():
            joined.append(l)
    statics, locals_ = [], set()
    pnames = {re.match(r'^&?(\w+)', x.strip()).group(1) for x in split_top_commas(params) if x.strip()}
    js = []
    for l in joined:
        ind = re.match(r'^\s*', l).group()
        st = l.strip()
        pre = ''
        while st.startswith('}'):
            pre += '} '
            st = st[1:].strip()
        brace = ''
        if st.endswith('{'):
            brace = ' {'
            st = st[:-1].strip()
        if not st:
            js.append(ind + pre + brace.strip())
            continue
        for v in re.findall(r'\b([A-Za-z_]\w*)\s*(?::=|\+=|-=|\*=|/=|\.=)', st):
            locals_.add(v)
        for v in re.findall(r'&([A-Za-z_]\w*)', st):
            locals_.add(v)
        m = re.match(r'^static\s+(.*)$', st)
        if m:
            for part in split_top_commas(m.group(1)):
                n = re.match(r'\s*(\w+)', part).group(1)
                statics.append((n, expr(part.strip())))
            continue
        out = None
        m = re.match(r'^(else\s+)?if\s+(.*)$', st)
        if m:
            out = (m.group(1) or '') + 'if (' + expr(m.group(2)) + ')'
        elif st == 'else':
            out = 'else'
        elif st.startswith('else '):
            out = 'else ' + stmt(st[5:])
        elif re.match(r'^while\s', st):
            out = 'while (' + expr(st[6:]) + ')'
        elif re.match(r'^loop\s+parse\s+', st, re.I):
            out = 'for (let [A_Index, A_LoopField] of AHK_PARSE(' + expr(re.sub(r'^loop\s+parse\s+', '', st, flags=re.I)) + '))'
        elif re.match(r'^loop(\s|$)', st, re.I):
            n = st[4:].strip()
            out = 'for (let A_Index = 1; ' + (f'A_Index <= ({expr(n)})' if n else '') + '; A_Index++)'
        else:
            m = re.match(r'^for\s+(\w+)(?:\s*,\s*(\w+))?\s+in\s+(.*)$', st)
            if m:
                a, b, x = m.groups()
                locals_.add(a)
                if b:
                    locals_.add(b)
                    out = f'for (let [A_Index, __a, __b] of AHK_FOR({expr(x)}, 2)) if (({a} = __a, {b} = __b, true))'
                else:
                    out = f'for (let [A_Index, __a] of AHK_FOR({expr(x)}, 1)) if (({a} = __a, true))'
            else:
                out = stmt(st)
        js.append(ind + pre + out + brace)
    snames = {n for n, _ in statics}
    locals_ -= pnames | snames | {'A_Index', 'A_LoopField'}
    head = f'function {name}({conv_params(params)}) {{\n'
    if locals_:
        head += '    let ' + ', '.join(sorted(locals_)) + ';\n'
    body_js = head + '\n'.join(js) + '\n}'
    if statics:
        return (f'const {name} = (() => {{\n    let ' + ', '.join(f'{v}' for n, v in statics) +
                ';\n    return ' + body_js.replace('\n', '\n    ') + ';\n})();')
    return body_js


def stmt(st):
    if st in ('continue', 'break', 'return'):
        return st + ';'
    if st.startswith('return '):
        return 'return ' + expr(st[7:]) + ';'
    return expr(st) + ';'


if __name__ == '__main__':
    src = open(sys.argv[1], encoding='utf-8-sig').read().replace('\r', '')
    funcs = get_funcs(src)
    out = ['// automatisch übersetzt aus ' + sys.argv[1] + ' – nicht von Hand ändern', '"use strict";']
    for name in sys.argv[3:]:
        if name not in funcs:
            sys.exit('Funktion fehlt: ' + name)
        p, b = funcs[name]
        out.append(conv_func(name, p, b))
    open(sys.argv[2], 'w').write('\n\n'.join(out) + '\n')
    print('ok', len(sys.argv) - 3, 'Funktionen')
