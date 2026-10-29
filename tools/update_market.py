"""Marktpreise pro Liga (Currency, Fragmente, Omen, Runen ...) -> data/market/<liga>.tsv (für den Reiter "Markt").

Quelle: poe.ninja Economy-API, Currency-Exchange-Übersicht (https://poe.ninja/docs/api).
Die App fragt poe.ninja nie selbst: Diese Datei läuft in unserer GitHub-Automatik, langsam und mit eigenem
User-Agent, und legt das Ergebnis im Repo ab. poe.ninja aktualisiert die PoE2-Übersichten etwa stündlich.

Aufruf live:     python3 update_market.py <data-Ordner>
Aufruf zum Test: python3 update_market.py <data-Ordner> --ninja fixture.json

Datei-Format (Tab-getrennt, Preise in Divine Orbs):
  H  <Liga> <Zeit UTC, ISO> <Bezugswährung> <Exalted je Divine> <Chaos je Divine>
  I  <Kategorie> <ID> <Name> <Preis> <Umsatz in Divine> <Änderung 7 Tage in %> <Verlauf, 7 Werte mit Komma>
     <Bild-Pfad hinter web.poecdn.com/gen/image/>
index.tsv:  L <Liga> <Datei> <Zeit> <Anzahl>"""
import datetime, json, pathlib, re, sys, time, urllib.parse, urllib.request

UA = 'ChaosWard/1.0 (+https://github.com/moemor/chaos-ward)'
API = 'https://poe.ninja/poe2/api/economy/'
TYPES = ['Currency', 'Fragments', 'Abyss', 'UncutGems', 'LineageSupportGems', 'Essences', 'SoulCores', 'Idols', 'Runes',
         'Ritual', 'Expedition', 'Delirium', 'Breach', 'Verisium']
MIN_ROWS = 20                     # weniger Zeilen: Abfrage kaputt -> alte Datei behalten
OUT = pathlib.Path(sys.argv[1]) / 'market'
OUT.mkdir(parents=True, exist_ok=True)
args = sys.argv[2:]
opt = {args[i].lstrip('-'): args[i + 1] for i in range(0, len(args) - 1, 2)}


def get(url):
    req = urllib.request.Request(url, headers={'User-Agent': UA, 'Accept': 'application/json'})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode('utf-8'))


def num(x, sig=4):
    x = float(x or 0)
    return '0' if x == 0 else f'{float(f"{x:.{sig}g}"):g}'


def clean(s):
    return re.sub(r'[\t\r\n]+', ' ', str(s or '')).strip()


if 'ninja' in opt:
    fx = json.load(open(opt['ninja'], encoding='utf-8'))
    leagues = fx['leagues'][:1]
    fetched = {leagues[0]['id']: fx['types']}
else:
    leagues = [l for l in get(API + 'leagues') if not re.search(r'\b(HC|SSF|Hardcore)\b', l['name'])][:3]
    fetched = {}
    for lg in leagues:
        fetched[lg['id']] = {}
        for ty in TYPES:
            time.sleep(1.5)
            try:
                fetched[lg['id']][ty] = get(f'{API}exchange/current/overview?league={urllib.parse.quote(lg["id"])}&type={ty}')
            except Exception as e:
                print(lg['id'], ty, 'failed:', e)

now = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%MZ')
index = []
for lg in leagues:
    name = lg['id']
    rows, primary, rates = [], 'divine', {}
    for ty in TYPES:
        j = fetched[name].get(ty)
        if not j:
            continue
        core = j.get('core') or {}
        primary = core.get('primary') or primary
        rates = core.get('rates') or rates
        info = {i['id']: i for i in (j.get('items') or []) + (core.get('items') or []) if i.get('id')}
        for l in j.get('lines') or []:
            it = info.get(l.get('id')) or {}
            if not it.get('name') or not l.get('primaryValue'):
                continue
            sp = l.get('sparkline') or {}
            spark = ','.join('' if v is None else num(v, 4) for v in (sp.get('data') or []))
            img = it.get('image') or ''
            m = re.match(r'^(?:https://web\.poecdn\.com)?/gen/image/([A-Za-z0-9_\-/.=]+)$', img)   # nur Bilder vom Bilder-Server von GGG
            rows.append(['I', ty, clean(l['id']), clean(it['name']), num(l['primaryValue']), num(l.get('volumePrimaryValue'), 5),
                         num(sp.get('totalChange'), 4), spark, m.group(1) if m else ''])
    if len(rows) < MIN_ROWS:
        print(name, 'only', len(rows), 'rows, keeping the old file')
        old = OUT / (re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-') + '.tsv')
        if old.exists():
            head = old.read_text(encoding='utf-8').split('\n')[1].split('\t')
            index.append(['L', name, old.name, head[2] if len(head) > 2 else '', str(old.read_text(encoding='utf-8').count('\nI\t'))])
        continue
    slug = re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')
    f = OUT / f'{slug}.tsv'
    with open(f, 'w', encoding='utf-8', newline='\n') as out:
        out.write('# Chaos Ward Markt: Preise von poe.ninja (Economy-API, Currency Exchange), Preise in Divine Orbs\n')
        out.write('\t'.join(['H', name, now, primary, num(rates.get('exalted')), num(rates.get('chaos'))]) + '\n')
        for r in rows:
            out.write('\t'.join(r) + '\n')
    index.append(['L', name, f.name, now, str(len(rows))])
    print(name, len(rows), 'prices')
if index:
    (OUT / 'index.tsv').write_text('# Chaos Ward Marktpreise pro Liga (aktuelle Season zuerst)\n' + '\n'.join('\t'.join(r) for r in index) + '\n',
                                   encoding='utf-8')
