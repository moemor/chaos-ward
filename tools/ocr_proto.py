"""Prototyp der Tooltip-Erkennung (gleicher Ablauf wie später in AutoHotkey).
OCR hier: tesseract als Ersatz für die Windows-Texterkennung."""
import re, subprocess, sys, csv, io
from PIL import Image

MODS = '/home/claude/app/Mods.tsv'
G, C = {}, {}
for line in open(MODS, encoding='utf-8-sig'):
    f = line.rstrip('\n').split('\t')
    if f[0] == 'G':
        rng = []
        for r in f[8].split('|'):
            a = r.split(':')
            rng.append((float(a[0]), float(a[1])) if len(a) == 2 else None)
        G[f[1]] = dict(id=f[1], kind=f[2], text=f[3], n=int(f[4]), ranges=rng)
    elif f[0] == 'C':
        C[f[1]] = f[4].split(',')


def key(s):
    return re.sub(r'[^a-z]', '', s.lower())


def lev(a, b):
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


def sim(a, b):
    return 1 - lev(a, b) / max(len(a), len(b), 1)


def group_keys(g):
    # "(25-119)% increased Spell Damage / +(17-45) to maximum Mana" -> ["increasedspelldamage", "tomaximummana"]
    return [key(re.sub(r'\([^)]*\)', '', part)) for part in g['text'].split(' / ')]


FIX = str.maketrans({'O': '0', 'o': '0', 'l': '1', 'I': '1', '|': '1', 'S': '5', 'B': '8'})


def first_number(s):
    # Zeichen in Zahlen-Token reparieren (O->0, l->1 ...), nur wenn der Token schon eine Ziffer enthält
    toks = re.findall(r'[+\-]?[0-9OolIS|B.]+%?', s)
    for t in toks:
        if re.search(r'\d', t):
            m = re.search(r'\d+(\.\d+)?', t.translate(FIX))
            if m:
                return float(m.group())
    return None


def tier_of(g, v):
    for i, r in enumerate(g['ranges'], 1):
        if r and r[0] <= v <= r[1]:
            return i
    return 0


def ocr_words(path, thr=200, scale=2):
    im = Image.open(path).convert('L')
    im = im.resize((im.width * scale, im.height * scale), Image.LANCZOS).point(lambda v: 0 if v > thr else 255)
    im.save('/tmp/_ocr.png')
    out = subprocess.run(['tesseract', '/tmp/_ocr.png', '-', '--psm', '11', 'tsv'], capture_output=True, text=True).stdout
    words = []
    for r in csv.DictReader(io.StringIO(out), delimiter='\t', quoting=csv.QUOTE_NONE):
        t = (r.get('text') or '').strip()
        if t and r['conf'] != '-1':
            words.append(dict(t=t, x=int(r['left']) / scale, y=int(r['top']) / scale, w=int(r['width']) / scale, h=int(r['height']) / scale))
    return words


def segments(words):
    words = sorted(words, key=lambda w: w['y'] + w['h'] / 2)
    lines = []
    for w in words:
        cy = w['y'] + w['h'] / 2
        for ln in lines:
            if abs(ln['cy'] - cy) < 0.6 * max(ln['h'], w['h']):
                ln['w'].append(w); ln['h'] = max(ln['h'], w['h']); break
        else:
            lines.append(dict(cy=cy, h=w['h'], w=[w]))
    segs = []
    for ln in lines:
        ws = sorted(ln['w'], key=lambda w: w['x'])
        cur = [ws[0]]
        for w in ws[1:]:
            gap = w['x'] - (cur[-1]['x'] + cur[-1]['w'])
            if gap > 2.2 * ln['h']:
                segs.append(cur); cur = [w]
            else:
                cur.append(w)
        segs.append(cur)
    out = []
    for s in segs:
        x1 = min(w['x'] for w in s); x2 = max(w['x'] + w['w'] for w in s)
        out.append(dict(text=' '.join(w['t'] for w in s), cx=(x1 + x2) / 2, y=min(w['y'] for w in s), h=max(w['h'] for w in s)))
    return sorted(out, key=lambda s: s['y'])


def analyse(path, names, cat, wishes, fractured=(), expected=0):
    segs = segments(ocr_words(path))
    # 1) Kopfzeile des gehoverten Items finden (Name aus dem einen Strg+C)
    best, head = 0, None
    for s in segs:
        for n in names:
            v = sim(key(s['text']), key(n))
            if v > best:
                best, head = v, s
    if best < 0.7:
        return dict(status='kein Tooltip gefunden', best=best)
    tol = 2.0 * head['h']
    mine = [s for s in segs if abs(s['cx'] - head['cx']) <= tol and s['y'] >= head['y'] - 3 * head['h']]
    # 2) Zeilen sammeln (fractured und Kurzes raus)
    fkeys = [key(re.sub(r'[\d+%.()\-]', '', f)) for f in fractured]
    lines = []
    for s in mine:
        k = key(s['text'])
        if len(k) < 6 or any(sim(k, fk) >= 0.85 for fk in fkeys):
            continue
        lines.append((s['text'], k))
    # 3) Gruppe für Gruppe: alle Zeilen einer Gruppe müssen gefunden werden (Hybride = 2 Zeilen)
    full, partial = {}, {}
    for gid in C[cat]:
        keys = group_keys(G[gid]); idx = []; worst = 1
        for pk in keys:
            best = max(((sim(k, pk), i) for i, (_, k) in enumerate(lines)), default=(0, -1))
            idx.append(best[1]); worst = min(worst, best[0])
        if worst >= 0.82:
            full[gid] = (len(keys), worst, idx)
        elif worst >= 0.65:
            partial[gid] = worst
    # jede Zeile gehört zur Gruppe mit den meisten Zeilen (Hybrid vor Einzel), dann bester Treffer
    owner = {}
    for gid, (n, worst, idx) in sorted(full.items(), key=lambda kv: (-kv[1][0], -kv[1][1])):
        if all(i not in owner for i in idx):
            for i in idx:
                owner[i] = gid
    groups = set(owner.values())
    hits, unsure = [], []
    for gid in groups:
        if gid not in wishes:
            continue
        g, want = G[gid], wishes[gid]
        first_line = lines[full[gid][2][0]][0]
        v = first_number(first_line)
        t = tier_of(g, v) if v is not None else 0
        if want == '':
            hits.append((first_line, f'T{t}'))
        elif t == 0:
            unsure.append(first_line + ' (Zahl unklar)')
        elif t <= int(want[1:]):
            hits.append((first_line, f'T{t}'))
    for gid in wishes:
        if gid not in groups and gid in partial:
            unsure.append(G[gid]['text'] + ' (Text unklar)')
    complete = len(groups) >= expected
    if not complete:
        unsure.append(f'nur {len(groups)} von {expected} Mods gelesen')
    lines = [(t, G[owner[i]]['text'] if i in owner else '-') for i, (t, k) in enumerate(lines)]
    return dict(status='ok', head=head['text'], lines=lines, hits=hits, unsure=unsure)


if __name__ == '__main__':
    U = '/root/.claude/uploads/6f69185b-55a2-544d-8723-bf0156e93c81/'
    wand = C['one_handed_weapons_wands']
    gid_spell = next(g for g in wand if G[g]['text'].endswith('% increased Spell Damage') and ' / ' not in G[g]['text'])
    gid_lvl = next(g for g in wand if 'Level of all Spell Skills' in G[g]['text'])
    gid_crit = next(g for g in wand if 'Critical Spell Damage Bonus' in G[g]['text'])
    cases = [
        ('Bild 2, Wunsch: Spell Damage nur T1', U + '80dd625e-image.png', ['Eagle Branch', 'Dueling Wand'], {gid_spell: 'T1'}, 2),
        ('Bild 2, Wunsch: Spell Damage T1-T7', U + '80dd625e-image.png', ['Eagle Branch', 'Dueling Wand'], {gid_spell: 'T7'}, 2),
        ('Bild 2, Wunsch: +Level Spell Skills (jedes Tier)', U + '80dd625e-image.png', ['Eagle Branch', 'Dueling Wand'], {gid_lvl: ''}, 2),
        ('Bild 1 (2 Tooltips), Wunsch: Crit Spell Dmg Bonus', U + 'e2a4fa05-image.png', ['Vortex Chant', 'Dueling Wand'], {gid_crit: ''}, 4),
        ('Bild 1 (2 Tooltips), Wunsch: Spell Damage', U + 'e2a4fa05-image.png', ['Vortex Chant', 'Dueling Wand'], {gid_spell: ''}, 4),
        ('Bild 1, Item hätte 5 Mods (eine Zeile verpasst)', U + 'e2a4fa05-image.png', ['Vortex Chant', 'Dueling Wand'], {gid_spell: ''}, 5),
    ]
    for title, path, names, wishes, exp in cases:
        r = analyse(path, names, 'one_handed_weapons_wands', wishes, expected=exp)
        print('==', title)
        if r['status'] != 'ok':
            print('  ', r); continue
        print('   Kopf:', r['head'])
        for l in r['lines']:
            print('     ', l[0], '->', l[1])
        print('   TREFFER:', r['hits'], ' UNSICHER:', r['unsure'])
