"""Neue Spieldaten -> data/Mods-<Patch>.tsv + data/index.tsv (fuer den Update-Knopf in Chaos Ward).
Aufruf: python3 update_moddb.py <repoe-poe2-Ordner> <data-Ordner>
Der RePoE-Ordner ist ein Klon von github.com/repoe-fork/poe2 (version.txt + data/*.json).
Gibt es den Patch schon, passiert nichts. index.tsv: P <Patch> <Datei> <Datum> <Gruppen> <Item-Arten> <SHA-256>"""
import datetime, hashlib, pathlib, subprocess, sys

REPOE = pathlib.Path(sys.argv[1])
OUT = pathlib.Path(sys.argv[2]); OUT.mkdir(parents=True, exist_ok=True)
ver = (REPOE / 'version.txt').read_text().strip()
name = f'Mods-{ver}.tsv'
target = OUT / name
FORMAT = 'F\t2'                                     # bei neuem Datei-Format (build_moddb.py) wird der Patch neu gebaut
if target.exists() and FORMAT in target.read_text(encoding='utf-8').splitlines():
    print('unchanged', ver)
    sys.exit(0)
tmp = OUT / (name + '.tmp')
subprocess.run([sys.executable, str(pathlib.Path(__file__).with_name('build_moddb.py')), str(REPOE / 'data'), str(tmp)], check=True)
lines = tmp.read_text(encoding='utf-8').splitlines()
groups = sum(1 for l in lines if l.startswith('G\t'))
cats = sum(1 for l in lines if l.startswith('C\t'))
head = next((l.split('\t')[1] for l in lines if l.startswith('V\t')), '')
if head != ver or groups < 500 or cats < 20:                    # unvollständig -> nichts veröffentlichen
    tmp.unlink()
    sys.exit(f'invalid build: version {head!r}, {groups} groups, {cats} item types')
tmp.rename(target)
sha = hashlib.sha256(target.read_bytes()).hexdigest()
idx = OUT / 'index.tsv'
rows = [l for l in (idx.read_text(encoding='utf-8').splitlines() if idx.exists() else []) if l.startswith('P\t')]
rows = [r for r in rows if r.split('\t')[1] != ver]
rows.insert(0, '\t'.join(['P', ver, name, datetime.date.today().isoformat(), str(groups), str(cats), sha]))
idx.write_text('# Chaos Ward Spieldaten (neueste zuerst)\n' + '\n'.join(rows) + '\n', encoding='utf-8')
print('new', ver, groups, 'groups', cats, 'item types')
