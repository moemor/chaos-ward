"""Bilder für die Item-Arten (eine passende Grundtyp-Grafik je Item-Art) + Chaos Orb, Divine Orb, Mageblood.
Quelle: Spielgrafiken aus RePoE (github.com/repoe-fork/poe2, Ordner data/Art, als .webp).
Je Item-Art wird der Grundtyp mit der höchsten Drop-Stufe genommen (so sieht das Endgame-Item aus).

Aufruf: python3 make_base_icons.py <RePoE-Klon> <Mods.tsv> <Ziel-Ordner, z.B. app/ui/img/items>
Fehlt eine Grafik im Klon (Teil-Checkout), wird sie mit "git show" aus dem Repo geholt."""
import json, pathlib, subprocess, sys

REPOE = pathlib.Path(sys.argv[1])
MODS = pathlib.Path(sys.argv[2])
OUT = pathlib.Path(sys.argv[3]); OUT.mkdir(parents=True, exist_ok=True)
BI = json.load(open(REPOE / 'data' / 'base_items.json'))
UQ = json.load(open(REPOE / 'data' / 'uniques.json'))
by_name = {}
for b in BI.values():
    if b.get('name') and b.get('release_state') == 'released':
        old = by_name.get(b['name'])
        if not old or (b.get('drop_level') or 0) > (old.get('drop_level') or 0):
            by_name[b['name']] = b


def art(dds, out_name):
    rel = 'data/' + dds.replace('.dds', '.webp')
    src = REPOE / rel
    try:
        data = src.read_bytes() if src.exists() else subprocess.run(['git', '-C', str(REPOE), 'show', 'HEAD:' + rel], capture_output=True, check=True).stdout
    except Exception as e:
        print('missing', dds, e)
        return False
    (OUT / out_name).write_bytes(data)
    return True


# Item-Arten aus Mods.tsv: C <id> ... / B <id> <Grundtyp>
bases = {}
for line in MODS.read_text(encoding='utf-8').splitlines():
    f = line.split('\t')
    if f[0] == 'B' and len(f) >= 3 and f[2] in by_name:
        bases.setdefault(f[1], []).append(by_name[f[2]])
n = 0
for cat, bs in bases.items():
    best = max(bs, key=lambda b: (b.get('drop_level') or 0, b['name']))
    vi = (best.get('visual_identity') or {}).get('dds_file')
    if vi and art(vi, cat + '.webp'):
        n += 1
extra = {'chaos.webp': 'Chaos Orb', 'divine.webp': 'Divine Orb'}
for fn, name in extra.items():
    art(by_name[name]['visual_identity']['dds_file'], fn)
mb = next(u for u in UQ.values() if u.get('name') == 'Mageblood')
art(mb['visual_identity']['dds_file'], 'mageblood.webp')
print(n, 'item type pictures of', len(bases), '+ chaos, divine, mageblood')
