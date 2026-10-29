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
        else:                                   # manche Bereiche stehen verkehrt herum in den Daten, z.B. (15-10)% reduced
            a, b = float(m.group(1)), float(m.group(2))
            out.append((min(a, b), max(a, b)))
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


def add_group(gen, typ, mods, src=''):
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
    gid = f'{gen[0].upper()}{SRC_MARK[src]}.{typ}.{ids[0]}.{ids[-1]}'
    taken = {r[0] for r in group_rows}
    base_gid, k = gid, 2
    while gid in taken:                       # gleicher Name, andere Tier-Liste (z.B. neue Waffenart) -> eindeutig machen
        gid, k = f'{base_gid}.{k}', k + 1
    assert not re.search(r'[:,|\t~]', gid), gid
    group_index[key] = gid
    rng = []
    for lvl, name, t in reversed(tiers):  # T1 (beste) zuerst
        nums = numbers(t.split('\n')[0])
        rng.append(f'{fmt(nums[0][0])}:{fmt(nums[0][1])}' if nums else '')
    group_rows.append([gid, 'P' if gen == 'prefix' else 'S', display, str(n), str(tiers[-1][0]), tier_txt, '||'.join(pats), '|'.join(rng), src])
    return gid


def emit(cat_id, main, sub, groups, bases):
    gids = []
    for (gen, typ), mods in sorted(groups.items()):
        g = add_group(gen, typ, mods)
        if g:
            gids.append(g)
    pats = {r[6] for r in group_rows if r[0] in gids}
    for (gen, typ, src), mods in sorted(extra_groups(bases).items()):
        g = add_group(gen, typ, mods, src)
        row = next((r for r in group_rows if r[0] == g), None)
        if g and row[6] not in pats:            # gleicher Text wie ein normaler Mod -> der normale reicht
            gids.append(g)
    if not gids:
        return
    cat_rows.append([cat_id, main, sub, ','.join(gids)])
    for b in sorted(bases):
        base_rows.append([cat_id, b])


# Sonder-Mods aus dem Bereich "desecrated" der Spieldaten:
#   breach = Breach-Baum (Genesis Tree): Ringe, Amulette, Guertel; ein Chaos Orb kann sie neu wuerfeln, wenn das Item schon einen hat
#   desec  = Desecrated (Amanamu, Ulaman, Kurgal ...): kommen nur ueber Abyssal Bones / Aufdecken, nicht per Chaos Orb
# Im Chaos-Reiter steht "breach" als eigener Abschnitt, "desec" nur fuer Erkennung und Divine-Bereiche.
SRC_MARK = {'': '', 'breach': 'B', 'breach_caster': 'BC', 'breach_minion': 'BM', 'desec': 'D'}
# Items aus dem Breach-Baum tragen zusaetzlich genesis_tree_caster oder genesis_tree_minion: damit koennen auch
# normale Mods wuerfeln, die es auf dieser Basis sonst nicht gibt (z.B. +1 to Level of all Spell Skills auf Ringen)
GENESIS = {'genesis_tree_caster': 'breach_caster', 'genesis_tree_minion': 'breach_minion'}
ITEM_MODS = {k: m for k, m in M.items() if m.get('domain') == 'item' and m.get('generation_type') in ('prefix', 'suffix')
             and m.get('text') and not m.get('is_essence_only') and any(sw['tag'] in GENESIS and sw['weight'] > 0 for sw in m.get('spawn_weights', []))}
BREACH_SLOTS = {'ring', 'amulet', 'belt'}
DESEC = {k: m for k, m in M.items() if m.get('domain') == 'desecrated' and m.get('generation_type') in ('prefix', 'suffix')
         and m.get('text') and not k.startswith('Unique') and not k.startswith('Historic')}
TAGS_BY_NAME = collections.defaultdict(set)
for b in BI.values():
    if b.get('name') and b.get('release_state') == 'released':
        TAGS_BY_NAME[b['name']].update(b.get('tags', []))


def spawns(m, tags):
    for sw in m.get('spawn_weights', []):
        if sw['tag'] in tags:
            return sw['weight'] > 0
    return False


def extra_groups(bases):
    out = collections.defaultdict(dict)
    for name in bases:
        tags = set(TAGS_BY_NAME.get(name, ())) | {'default'}
        if tags & BREACH_SLOTS:
            tags.add('breach_desecration')
        for mid, m in DESEC.items():
            if spawns(m, tags):
                src = 'breach' if mid.startswith('GenesisTree') else 'desec'
                out[(m['generation_type'], m['type'], src)][mid] = m.get('required_level', 1)
        if tags & BREACH_SLOTS:
            for gtag, src in GENESIS.items():
                for mid, m in ITEM_MODS.items():
                    if spawns(m, tags | {gtag}) and not spawns(m, tags):
                        out[(m['generation_type'], m['type'], src)][mid] = m.get('required_level', 1)
    return out


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

# Neue Waffenarten automatisch aufnehmen (z.B. Schwerter, Äxte, Flegel, sobald es sie gibt).
# Nur fuer 0.5.5.4.2 bekannt: die Daten melden diese Klassen schon als "released", im Spiel gibt es sie aber noch nicht.
NOT_IN_GAME_YET = {'0.5.5.4.2': {'One Hand Swords', 'Two Hand Swords', 'One Hand Axes', 'Two Hand Axes', 'Flails', 'Fishing Rods'}}
covered = set()
for main, spec in TREE:
    if isinstance(spec, list):
        covered.update(cls for _, cls in spec)
    elif ':' in spec:
        covered.add(spec.split(':', 1)[1])
covered.update({'Shields', 'Bucklers', 'Foci', 'Quivers'})
for cls in sorted(MB):
    if cls in covered or cls in NOT_IN_GAME_YET.get(VERSION, set()) or 'Hidden' in cls:
        continue
    rel = [b for ts in MB[cls].values() for b in released(ts)]
    tags = {t for b in rel for t in BI[b].get('tags', [])}
    main = 'One Handed Weapons' if 'one_hand_weapon' in tags else 'Two Handed Weapons' if 'two_hand_weapon' in tags else ''
    if not rel or not main:
        continue
    g, b = collect(cls)
    emit(slug(main + '_' + cls), main, cls, g, b)
    print('  new weapon class', cls)
# gleiche Hauptgruppe zusammen lassen (neue Waffen hinter die bekannten derselben Gruppe)
order = {m: i for i, (m, _) in enumerate(TREE)}
cat_rows.sort(key=lambda r: order.get(r[1], 99))

with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
    f.write('﻿# PoE2 Craft-Schutz Mod-Datenbank - Quelle: Spieldaten via RePoE (repoe-fork/poe2)\n')
    f.write(f'V\t{VERSION}\n')
    f.write('F\t2\n')                      # Format 2: Spalte 10 = Herkunft (breach/desec)
    for r in group_rows:
        f.write('G\t' + '\t'.join(r) + '\n')
    for r in cat_rows:
        f.write('C\t' + '\t'.join(r) + '\n')
    for r in base_rows:
        f.write('B\t' + '\t'.join(r) + '\n')

print('version', VERSION, 'groups', len(group_rows), 'cats', len(cat_rows), 'bases', len(base_rows))
for r in cat_rows:
    print(f'  {r[1]:20s} {r[2]:34s} {len(r[3].split(","))} mods')
