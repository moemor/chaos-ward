"""Unique-Preise pro Season + mögliche Corruption-Enchants -> data/uniques/<liga>.tsv (für den Reiter "Uniques").

Quellen (beide erlaubt):
  * Preise: poe.ninja Economy-API (offiziell freigegeben, https://poe.ninja/docs/api), mit eigenem User-Agent,
    langsam abgefragt und hier zwischengespeichert, damit die App poe.ninja nie direkt abfragt.
  * Corruption-Enchants: Spieldaten (RePoE, mods.json + base_items.json).
  * Trade-IDs der Enchants: offizielle Trade-Seite (api/trade2/data/stats), damit die App passende Suchen öffnen kann.

Aufruf live:     python3 update_uniques.py <repoe-Ordner> <data-Ordner>
Aufruf zum Test: python3 update_uniques.py <repoe-Ordner> <data-Ordner> --ninja fixture.json --trade trade.txt

Datei-Format (Tab-getrennt):
  H  <Liga> <Datum> <Währung der Preise> <Exalted je Einheit>
  E  <Enchant-Nr> <Text mit Bereichen> <Trade-ID oder leer>
  U  <Name> <Grundtyp> <Kategorie> <Preis> <Angebote> <Enchant-Nrn mit Komma> <Bild-Pfad hinter web.poecdn.com/gen/image/>
index.tsv:  L <Liga> <Datei> <Datum> <Anzahl Uniques>"""
import datetime, json, pathlib, re, sys, time, urllib.request

UA = 'ChaosWard/1.0 (+https://github.com/moemor/chaos-ward)'
ICON = 'https://web.poecdn.com/gen/image/'
TYPES = ['UniqueWeapons', 'UniqueArmours', 'UniqueAccessories', 'UniqueFlasks', 'UniqueCharms', 'UniqueJewels']
REPOE = pathlib.Path(sys.argv[1])
OUT = pathlib.Path(sys.argv[2]) / 'uniques'
OUT.mkdir(parents=True, exist_ok=True)
args = sys.argv[3:]
opt = {args[i].lstrip('-'): args[i + 1] for i in range(0, len(args) - 1, 2)}


def get(url):
    req = urllib.request.Request(url, headers={'User-Agent': UA, 'Accept': 'application/json'})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode('utf-8'))


def clean(t):
    t = re.sub(r'\[([^\]|]+)\|([^\]]+)\]', r'\2', t)
    return re.sub(r'\[([^\]]+)\]', r'\1', t)


def skel(t):
    t = clean(t)
    t = re.sub(r'\(\s*-?[\d.]+\s*-\s*-?[\d.]+\s*\)', '#', t)
    t = re.sub(r'-?\d+(?:\.\d+)?', '#', t)
    t = t.replace('+#', '#').replace('(Local)', '')
    return re.sub(r'\s+', ' ', t).strip().lower()


# --- Spieldaten: Corruption-Enchants und Grundtypen ---
D = REPOE / 'data'
M = json.load(open(D / 'mods.json'))
BI = json.load(open(D / 'base_items.json'))
base_tags = {}
for b in BI.values():
    if b.get('name'):
        base_tags.setdefault(b['name'], set()).update(b.get('tags', []))
corr = {mid: m for mid, m in M.items() if m.get('generation_type') == 'corrupted' and m.get('domain') == 'item' and m.get('text')}


def applies(m, tags):
    for sw in m.get('spawn_weights', []):
        if sw['tag'] in tags:
            return sw['weight'] > 0
    return False


# --- Trade-IDs ---
trade = {}
if 'trade' in opt:
    lines = [l.split('|', 1) for l in pathlib.Path(opt['trade']).read_text(encoding='utf-8').splitlines() if '|' in l]
    entries = [('enchant.stat_' + a, b) for a, b in lines]
else:
    try:
        st = get('https://www.pathofexile.com/api/trade2/data/stats')
        entries = [(e['id'], e['text']) for g in st['result'] if g['id'] == 'enchant' for e in g['entries']]
    except Exception as e:
        print('trade stats unavailable:', e)
        entries = []
for tid, text in entries:
    k = skel(text)
    local = '(Local)' in text
    trade.setdefault(k, {})[local] = tid

# Enchant-Nummern (stabil innerhalb einer Datei): gleicher Text = gleiche Nummer
ench_ids, ench_rows = {}, []


def ench_id(m, mid):
    text = clean(m['text']).replace('\n', ' / ')
    if text in ench_ids:
        return ench_ids[text]
    k = skel(m['text'])
    t = trade.get(k, {})
    tid = t.get('Local' in mid) or t.get(not ('Local' in mid)) or ''
    n = len(ench_rows) + 1
    ench_ids[text] = n
    ench_rows.append((n, text, tid))
    return n


# --- Preise pro Liga ---
if 'ninja' in opt:
    fx = json.load(open(opt['ninja']))
    leagues = [fx['leagues'][0]]
    data = {leagues[0]['id']: [dict(type=l[0], name=l[1], baseType=l[2], category=l[3], primaryValue=l[4], listingCount=l[5], icon=l[8] if len(l) > 8 else '') for l in fx['lines']]}
    primary = fx['core']['primary']
    rates = fx['core'].get('rates', {})
else:
    leagues = [l for l in get('https://poe.ninja/poe2/api/economy/leagues') if not re.search(r'\b(HC|SSF|Hardcore)\b', l['name'])][:3]
    data, primary, rates = {}, 'divine', {}
    for lg in leagues:
        rows = []
        for ty in TYPES:
            time.sleep(2)
            j = get(f'https://poe.ninja/poe2/api/economy/stash/current/item/overview?league={urllib.parse.quote(lg["id"])}&type={ty}')
            primary = (j.get('core') or {}).get('primary', primary)
            rates = (j.get('core') or {}).get('rates', rates) or rates
            for l in j.get('lines', []):
                rows.append(dict(type=ty, name=l.get('name'), baseType=l.get('baseType'), category=l.get('category'),
                                 primaryValue=l.get('primaryValue'), listingCount=l.get('listingCount'), icon=l.get('icon') or ''))
        data[lg['id']] = rows

today = datetime.date.today().isoformat()
index = []
for lg in leagues:
    name = lg['id']
    seen, urows = set(), []
    for r in sorted(data[name], key=lambda r: -(r['primaryValue'] or 0)):
        if not r['name'] or not r['baseType'] or (r['name'], r['baseType']) in seen:
            continue
        seen.add((r['name'], r['baseType']))
        tags = base_tags.get(r['baseType'], set())
        ids = sorted({ench_id(m, mid) for mid, m in corr.items() if applies(m, tags)})
        cat = re.sub(r'[\[\]]', '', (r['category'] or '').split('|')[-1]) or r['type'].replace('Unique', '')
        icon = r.get('icon') or ''
        icon = icon[len(ICON):] if icon.startswith(ICON) else ''    # nur Bilder vom offiziellen Bilder-Server von GGG
        urows.append(['U', r['name'], r['baseType'], cat, f"{(r['primaryValue'] or 0):g}", str(r['listingCount'] or 0), ','.join(map(str, ids)), icon])
    slug = re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')
    f = OUT / f'{slug}.tsv'
    with open(f, 'w', encoding='utf-8', newline='\n') as out:
        out.write('# Chaos Ward Uniques: Preise von poe.ninja (Economy-API), Enchants aus den Spieldaten\n')
        out.write('\t'.join(['H', name, today, primary, f"{rates.get('exalted', 0):g}"]) + '\n')
        for n, text, tid in ench_rows:
            out.write('\t'.join(['E', str(n), text, tid]) + '\n')
        for row in urows:
            out.write('\t'.join(row) + '\n')
    index.append(['L', name, f.name, today, str(len(urows))])
    print(name, len(urows), 'uniques', len(ench_rows), 'enchants', sum(1 for _, _, t in ench_rows if t), 'with trade id')
(OUT / 'index.tsv').write_text('# Chaos Ward Uniques pro Liga (aktuelle Season zuerst)\n' + '\n'.join('\t'.join(r) for r in index) + '\n', encoding='utf-8')
