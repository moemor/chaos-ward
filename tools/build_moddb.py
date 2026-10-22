"""Erzeugt Mods.tsv fuer PoE2 Craft-Schutz aus RePoE-PoE2-Daten (repoe-fork/poe2)."""
import json, re, sys, collections, pathlib

DATA = pathlib.Path(sys.argv[1])
OUT = pathlib.Path(sys.argv[2])
M = json.load(open(DATA / 'mods.json'))
MB = json.load(open(DATA / 'mods_by_base.json'))
BI = json.load(open(DATA / 'base_items.json'))
VERSION = (DATA.parent / 'version.txt').read_text().strip()

ARMOUR_SUBS = [  # (tag, Name)
    ('str_armour', 'Armour (STR)'),
    ('dex_armour', 'Evasion (DEX)'),
    ('int_armour', 'Energy Shield (INT)'),
    ('str_dex_armour', 'Armour/Evasion (STR/DEX)'),
    ('str_int_armour', 'Armour/Energy Shield (STR/INT)'),
    ('dex_int_armour', 'Evasion/Energy Shield (DEX/INT)'),
    ('str_dex_int_armour', 'Armour/Evasion/ES (STR/DEX/INT)'),
]
SHIELD_SUBS = [('str_shield', 'Tower Shield (STR)'), ('str_dex_shield', 'Targe (STR/DEX)'), ('str_int_shield', 'Crest Shield (STR/INT)')]

# Nicht erschienene Klassen (laut Nutzer: kommen erst mit dem naechsten Update)
TREE = [
    ('One Handed Weapons', [('Claws', 'Claws'), ('Daggers', 'Daggers'), ('Wands', 'Wands'),
                            ('One Hand Maces', 'One Hand Maces'), ('Sceptres', 'Sceptres'), ('Spears', 'Spears')]),
    ('Two Handed Weapons', [('Two Hand Maces', 'Two Hand Maces'), ('Quarterstaves', 'Quarterstaves'), ('Bows', 'Bows'),
                            ('Crossbows', 'Crossbows'), ('Staves', 'Staves'), ('Talismans', 'Talismans')]),
    ('Jewellery', [('Amulets', 'Amulets'), ('Rings', 'Rings')]),
    ('Belt', [('Belts', 'Belts')]),
    ('Gloves', 'ARMOUR:Gloves'),
    ('Boots', 'ARMOUR:Boots'),
    ('Body Armour', 'ARMOUR:Body Armours'),
    ('Helmets', 'ARMOUR:Helmets'),
    ('Offhand', 'OFFHAND'),
    ('Jewels', 'BYBASE:Jewels'),
    ('Flasks', [('Life Flasks', 'Life Flasks'), ('Mana Flasks', 'Mana Flasks'), ('Charms', 'Charms')]),
    ('Relics', 'BYBASE:Relics'),
    ('Tablets', 'BYBASE:Tablet'),
    ('Waystones', [('Waystones', 'Waystones')]),
]


def released(tagset):
    return [b for b in tagset['bases'] if BI.get(b, {}).get('release_state') == 'released']


def collect(cls, pred=lambda key, ts: True):
    """Mods (prefix/suffix) + Basisnamen aller Tagsets einer Klasse, die pred erfuellen."""
    groups = collections.defaultdict(dict)  # (gen,type) -> {modid: level}
    bases = set()
    for key, ts in MB[cls].items():
        rel = released(ts)
        if not rel or not isinstance(ts['mods'], dict) or not pred(key.split(','), ts):
            continue
        bases.update(BI[b]['name'] for b in rel)
        for gen in ('prefix', 'suffix'):
            for typ, ms in ts['mods'].get(gen, {}).items():
                for mid, lvl in ms.items():
                    if M[mid].get('is_essence_only'):
                        continue
                    groups[(gen, typ)][mid] = lvl
    return groups, bases


def clean(text):
    text = re.sub(r'\[([^\]|]+)\|([^\]]+)\]', r'\2', text)
    return re.sub(r'\[([^\]]+)\]', r'\1', text)


NUM_RE = re.compile(r'\((-?\d+(?:\.\d+)?)-(-?\d+(?:\.\d+)?)\)|(-?\d+(?:\.\d+)?)')


def numbers(line):
    out = []
    for m in NUM_RE.finditer(line):
        if m.group(3) is not None:
            v = float(m.group(3)); out.append((v, v))
        else:
            out.append((float(m.group(1)), float(m.group(2))))
    return out


def skeleton(line):
    return NUM_RE.sub('#', line)


def fmt(v):
    return str(int(v)) if v == int(v) else ('%g' % v)


def to_regex(skel):
    parts = skel.split('#')
    rx = r'[+-]?\d+(?:\.\d+)?'
    return '^' + rx.join(re.escape(p) for p in parts) + '$'


group_index = {}   # key -> gid
group_rows = []
cat_rows = []
base_rows = []


def add_group(gen, typ, mods):
    ids = sorted(mods, key=lambda i: (mods[i], i))
    key = (gen, typ, tuple(ids))
    if key in group_index:
        return group_index[key]
    tiers = []
    for i in ids:
        t = clean(M[i]['text'] or '')
        if t:
            tiers.append((mods[i], M[i]['name'], t))
    if not tiers:
        return None
    top = tiers[-1][2]
    lines_top = top.split('\n')
    # Gesamtbereich je Zahl, wenn alle Tiers dieselbe Form haben
    skels = {tuple(skeleton(l) for l in t[2].split('\n')) for t in tiers}
    if len(skels) == 1:
        disp_lines = []
        for li, line in enumerate(lines_top):
            nums_per_tier = [numbers(t[2].split('\n')[li]) for t in tiers]
            sk = skeleton(line).split('#')
            out = sk[0]
            for ni in range(len(sk) - 1):
                lo = min(n[ni][0] for n in nums_per_tier)
                hi = max(n[ni][1] for n in nums_per_tier)
                out += (fmt(lo) if lo == hi else f'({fmt(lo)}-{fmt(hi)})') + sk[ni + 1]
            disp_lines.append(out)
        display = ' / '.join(disp_lines)
    else:
        display = top.replace('\n', ' / ')
    pats = []
    for sk in sorted(skels):
        pats.append('¦'.join(to_regex(s) for s in sk))
    n = len(tiers)
    tier_txt = ';;'.join(f'T{n - k}~{lvl}~{name}~{t.replace(chr(10), " / ")}'
                         for k, (lvl, name, t) in enumerate(tiers))
    gid = f'{gen[0].upper()}.{typ}.{ids[0]}.{ids[-1]}'
    assert not re.search(r'[:,|\t~]', gid) and gid not in {r[0] for r in group_rows}, gid
    group_index[key] = gid
    rng = []
    for lvl, name, t in reversed(tiers):  # T1 (beste) zuerst
        nums = numbers(t.split('\n')[0])
        rng.append(f'{fmt(nums[0][0])}:{fmt(nums[0][1])}' if nums else '')
    group_rows.append([gid, 'P' if gen == 'prefix' else 'S', display, str(n), str(tiers[-1][0]), tier_txt, '||'.join(pats), '|'.join(rng)])
    return gid


def emit(cat_id, main, sub, groups, bases):
    gids = []
    for (gen, typ), mods in sorted(groups.items()):
        g = add_group(gen, typ, mods)
        if g:
            gids.append(g)
    if not gids:
        return
    cat_rows.append([cat_id, main, sub, ','.join(gids)])
    for b in sorted(bases):
        base_rows.append([cat_id, b])


def slug(s):
    return re.sub(r'[^a-z0-9]+', '_', s.lower()).strip('_')


for main, spec in TREE:
    if isinstance(spec, list):
        for sub, cls in spec:
            g, b = collect(cls)
            emit(slug(main + '_' + sub), main, sub, g, b)
    elif spec.startswith('ARMOUR:'):
        cls = spec.split(':', 1)[1]
        for tag, name in ARMOUR_SUBS:
            g, b = collect(cls, lambda tags, ts, tag=tag: tag in tags)
            emit(slug(main + '_' + tag), main, name, g, b)
    elif spec == 'OFFHAND':
        for tag, name in SHIELD_SUBS:
            g, b = collect('Shields', lambda tags, ts, tag=tag: tag in tags)
            emit(slug('offhand_' + tag), main, name, g, b)
        for cls in ('Bucklers', 'Foci', 'Quivers'):
            g, b = collect(cls)
            emit(slug('offhand_' + cls), main, cls, g, b)
    elif spec.startswith('BYBASE:'):
        cls = spec.split(':', 1)[1]
        seen = {}
        for key, ts in MB[cls].items():
            rel = released(ts)
            if not rel or not isinstance(ts['mods'], dict):
                continue
            names = sorted({BI[b]['name'] for b in rel})
            label = ', '.join(names) if len(names) <= 3 else names[0] + ' ...'
            g, b = collect(cls, lambda tags, t2, key=key: ','.join(tags) == key)
            emit(slug(main + '_' + label), main, label, g, b)

with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
    f.write('﻿# PoE2 Craft-Schutz Mod-Datenbank - Quelle: Spieldaten via RePoE (repoe-fork/poe2)\n')
    f.write(f'V\t{VERSION}\n')
    for r in group_rows:
        f.write('G\t' + '\t'.join(r) + '\n')
    for r in cat_rows:
        f.write('C\t' + '\t'.join(r) + '\n')
    for r in base_rows:
        f.write('B\t' + '\t'.join(r) + '\n')

print('version', VERSION, 'groups', len(group_rows), 'cats', len(cat_rows), 'bases', len(base_rows))
for r in cat_rows:
    print(f'  {r[1]:20s} {r[2]:34s} {len(r[3].split(","))} mods')
