"""Prototyp der Divine-Zahlen-Erkennung (gleiche Regeln wie AutoEvalDV in ChaosWard.ahk), mit tesseract."""
import re, sys, csv, io, subprocess, numpy as np
from PIL import Image
import ocr_proto as P
def words(path, thr, mode='max', scale=2):
    a = np.array(Image.open(path).convert('RGB')).astype(float)
    g = a.max(2) if mode == 'max' else 0.299*a[...,0]+0.587*a[...,1]+0.114*a[...,2]
    im = Image.fromarray(g.clip(0,255).astype('uint8')); im = im.resize((im.width*scale, im.height*scale), Image.LANCZOS).point(lambda v: 0 if v > thr else 255)
    im.save('/tmp/_dv.png')
    out = subprocess.run(['tesseract','/tmp/_dv.png','-','--psm','11','tsv'],capture_output=True,text=True).stdout
    return [dict(t=r['text'].strip(),x=int(r['left'])/scale,y=int(r['top'])/scale,w=int(r['width'])/scale,h=int(r['height'])/scale)
            for r in csv.DictReader(io.StringIO(out), delimiter='\t', quoting=csv.QUOTE_NONE) if (r.get('text') or '').strip() and r['conf']!='-1']
FIX = {'O':'0','o':'0','l':'1','I':'1','|':'1','S':'5','B':'8'}
def ocr_numbers(s):
    out = []
    for tok in re.findall(r'[+\-]?[0-9OolIS|B.]+%?', s):
        if not re.search(r'\d', tok): continue
        for a, b in FIX.items(): tok = tok.replace(a, b)
        m = re.search(r'\d+(?:\.\d+)?', tok)
        if m: out.append(float(m.group()))
    return out
def key(s): return re.sub(r'[^a-z]', '', s.lower())
def evaluate(path, names, truth_lines, thr):
    segs = P.segments(words(path, thr))
    best, head = 0, None
    for s in segs:
        for n in names:
            k, nk = key(s['text']), key(n)
            v = max(P.sim(k, nk), 0.9 if len(nk) >= 6 and nk in k and len(k) <= 3*len(nk) else 0)
            if v > best: best, head = v, s
    if best < 0.7: return None
    tip = [s for s in segs if abs(s['cx']-head['cx']) <= 2*head['h'] and s['y'] >= head['y']-3*head['h']]
    res = {}; seen = {}
    prop = lambda t: re.search(r'[:;]\s*[+\-]?\d', t) is not None
    bases = [key(re.sub(r'[\d.]+', '', t)) for t, n in truth_lines]
    owner = {}
    for si, sg in enumerate(tip):
        k = key(sg['text'])
        if len(k) < 4 or prop(sg['text']): continue
        bs, bk = max(((P.sim(k, b), b) for b in bases), default=(0, ''))
        if bs >= 0.82: owner[si] = bk
    for text, nums in truth_lines:
        base = key(re.sub(r'[\d.]+', '', text)); seen[base] = seen.get(base, 0) + 1; occ = seen[base]
        c = sorted([sg for si, sg in enumerate(tip) if owner.get(si) == base], key=lambda s: s['y'])
        clusters = []
        for s in c:
            for cl in clusters:
                if abs(cl[0]['y'] - s['y']) < 0.6 * max(cl[0]['h'], s['h']): cl.append(s); break
            else: clusters.append([s])
        got = None; flag = ''
        if len(clusters) >= occ:
            for s in clusters[occ-1]:
                ns = ocr_numbers(s['text'])
                if len(ns) == len(nums): got = ns; break
        if got is not None:
            for v, t in zip(got, nums):     # Bereich: wie Tier-Spanne grob +-25 %
                if not (t * 0.75 <= v <= t * 1.25 + 1): flag = 'UNSICHER'
        res[text] = (got, flag)
    return res
U = '/root/.claude/uploads/6f69185b-55a2-544d-8723-bf0156e93c81/'
cases = [
  ('Armbrust (du)', U+'45cae271-image.png', ['Plague Core','Bleak Crossbow'],
   [('79% increased Physical Damage',[79]),('Adds 14 to 20 Fire Damage',[14,20]),('Adds 4 to 155 Lightning Damage',[4,155]),
    ('+4.03% to Critical Hit Chance',[4.03]),('+22% to Critical Damage Bonus',[22]),('+31 to Strength',[31])]),
  ('Stab (Kollege, SDR)', U+'7f8975e2-image.png', ['Vortex Weaver','Chiming Staff'],
   [('Gain 29% of Damage as Extra Cold Damage',[29]),('169% increased Spell Damage',[169]),('+319 to maximum Mana',[319]),
    ('91% increased Mana Regeneration Rate',[91]),('5% increased Light Radius',[5]),('+1 to Level of all Physical Spell Skills',[1])]),
  ('Headhunter (Kollege, SDR)', U+'01cdf5a2-image.png', ['Headhunter','Heavy Belt'],
   [('+10 to Strength',[10]),('+49 to maximum Life',[49]),('+39 to Strength',[39]),('+33 to Dexterity',[33]),('27% increased Stun Threshold',[27]),
    ('When you kill a Rare monster, you gain its Modifiers for 60 seconds',[60])]),
  ('Zepter (du, HDR)', U+'e2a4fa05-image.png', ['Behemoth Crusher','Stoic Sceptre'],
   [('46% increased Spirit',[46]),('+163 to maximum Mana',[163]),('60% increased Mana Regeneration Rate',[60]),('26% increased Spirit',[26]),
    ('+33 to maximum Mana',[33]),('Allies in your Presence have +18% to all Elemental Resistances',[18])]),
]
tot = ok = 0
for title, path, names, lines in cases:
    for thr in (215, 190, 160):
        r = evaluate(path, names, lines, thr)
        if r is None: print(f'{title:26} {thr}: Kopf nicht gefunden'); continue
        good = sum(1 for t, n in lines if r[t][0] == [float(x) for x in n])
        wrong = [(t, r[t][0], r[t][1] or 'NICHT ERKANNT!') for t, n in lines if r[t][0] is not None and r[t][0] != [float(x) for x in n]]
        miss = [t for t, n in lines if r[t][0] is None]
        tot += len(lines); ok += good
        print(f'{title:26} {thr}: richtig {good}/{len(lines)}  falsch={wrong}  nicht gefunden={len(miss)}')
print('GESAMT', ok, '/', tot)
