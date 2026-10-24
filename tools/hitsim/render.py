"""Rendert den übersetzten AHK-Zeichencode der Treffer-Leiste: Einzelbilder, Kontaktbogen und Video.
Aufruf: python3 render.py <ausgabeordner> [chaos|dv|all] [--video]"""
import asyncio, base64, json, os, shutil, subprocess, sys, time
from pathlib import Path
from playwright.async_api import async_playwright

HERE = Path(__file__).parent
OUT = Path(sys.argv[1]); OUT.mkdir(parents=True, exist_ok=True)
WHICH = sys.argv[2] if len(sys.argv) > 2 else 'all'
VIDEO = '--video' in sys.argv
ROOT = Path('/tmp/claude-0/-home-claude/6f69185b-55a2-544d-8723-bf0156e93c81/scratchpad/hitsim_root')
BG = Path('/tmp/claude-0/-home-claude/6f69185b-55a2-544d-8723-bf0156e93c81/scratchpad/hitsim_bg.png')

CHAOS = dict(style='', hits=1, orbs=148, reel={'Lines': ['15% increased Attack Speed', 'Adds 14 to 20 Fire Damage', '172% increased Physical Damage',
             'Adds 4 to 155 Lightning Damage', '+21 to Strength'], 'Target': 3, 'Sub': 'T1  increased Physical Damage'})
DV_STATE = {'Any': 0, 'Item': 'Vortex Weaver', 'Lines': [
    {'Key': 'spell', 'Text': '169% increased Spell Damage', 'Nums': [{'V': 169, 'Lo': 150, 'Hi': 179}]},
    {'Key': 'mana', 'Text': '+319 to maximum Mana', 'Nums': [{'V': 319, 'Lo': 271, 'Hi': 329}]},
    {'Key': 'cold', 'Text': 'Adds 18 to 31 Cold Damage', 'Nums': [{'V': 18, 'Lo': 15, 'Hi': 22}, {'V': 31, 'Lo': 26, 'Hi': 36}]},
    {'Key': 'crit', 'Text': '+1.25% to Critical Hit Chance', 'Nums': [{'V': 1.25, 'Lo': 1.01, 'Hi': 1.5}]}],
    'Rules': {'spell': {1: ['>=', 172]}, 'mana': {1: ['>=', 315]}, 'crit': {1: ['>=', 1.3]}}}
DV_VALS = {'spell': [176], 'mana': [325], 'cold': [19, 33], 'crit': [1.42]}
TIMES = [0.05, 0.15, 0.3, 0.45, 0.52, 0.58, 0.75, 1.05]


def setup_root():
    if ROOT.exists():
        shutil.rmtree(ROOT)
    ROOT.mkdir(parents=True)
    os.symlink('/home/claude/app/ui', ROOT / 'ui')
    for f in ['harness.html', 'gdip_shim.js', 'scene.js', 'strings_de.json', 'strings_en.json']:
        os.symlink(HERE / f, ROOT / f)
    shutil.copy(BG, ROOT / 'bg.png')


JS_DV = """(d) => { const rules = new Map(); for (const [k, m] of Object.entries(d.Rules)) { const mm = new Map(); for (const [i, r] of Object.entries(m)) mm.set(+i, {Op: r[0], Val: r[1]}); rules.set(k, mm); }
  const st = {Any: d.Any, Item: d.Item, Lines: d.Lines, Rules: rules}; return st; }"""


async def main():
    setup_root()
    srv = subprocess.Popen([sys.executable, '-m', 'http.server', '8771', '-d', str(ROOT)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1)
    errors = []
    try:
        async with async_playwright() as p:
            b = await p.chromium.launch()
            pg = await b.new_page(viewport={'width': 1400, 'height': 700})
            pg.on('pageerror', lambda e: errors.append(str(e)))
            pg.on('console', lambda m: m.type == 'error' and errors.append(m.text))
            await pg.goto('http://localhost:8771/harness.html?hs=' + os.environ.get('HS', '1.5') + '&lang=' + os.environ.get('LANG_HIT', 'de'))
            await pg.evaluate('window.ready')
            for name in (['chaos', 'dv', 'multi', 'mb', 'long', 'uq'] if WHICH == 'all' else [WHICH]):
                if name == 'chaos':
                    await pg.evaluate(f"window.INFO = makeInfo('', 1, 148, {json.dumps(CHAOS['reel'])})")
                elif name == 'multi':
                    await pg.evaluate(f"window.INFO = makeInfo('', 2, 61, {json.dumps(CHAOS['reel'])})")
                elif name == 'long':
                    r = dict(CHAOS['reel']); r['Lines'] = list(r['Lines']); r['Lines'][2] = 'Gain 29% of Damage as Extra Cold Damage (21-35)%'; r['Sub'] = 'T1  Gain of Damage as Extra Cold Damage'
                    await pg.evaluate(f"window.INFO = makeInfo('', 1, 1234, {json.dumps(r)})")
                elif name == 'uq':
                    await pg.evaluate("window.INFO = makeInfo('uq', 1, 7, {Lines: ['14% increased Rarity of Items found'], Target: 1, Sub: '14% increased Rarity of Items found'})")
                elif name == 'mb':
                    await pg.evaluate(f"window.INFO = makeInfo('mb', 1, 340, {json.dumps(CHAOS['reel'])}); INFO.Sub = 'Ruby ×2  ·  Sapphire  ·  Jade'")
                else:
                    await pg.evaluate(f"""(() => {{ const dv = ({JS_DV})({json.dumps(DV_STATE)}); Dv = dv;
                        const vals = new Map(Object.entries({json.dumps(DV_VALS)}));
                        window.INFO = makeInfo('dv', 1, 23, ReelDv(vals)); }})()""")
                info = await pg.evaluate("JSON.stringify({Sub: INFO.Sub, Reel: INFO.Reel})")
                print(name, info[:300])
                stills = []
                for t in TIMES:
                    url = await pg.evaluate(f"frame({t}, INFO)")
                    f = OUT / f'{name}_{int(t * 1000):05d}.png'
                    f.write_bytes(base64.b64decode(url.split(',')[1]))
                    stills.append(f)
                # Kontaktbogen
                from PIL import Image
                ims = [Image.open(x) for x in stills]
                w, h = ims[0].size
                sheet = Image.new('RGB', (w * 2 // 2, h * len(ims) // 2), 'black')
                sheet = Image.new('RGB', (w, h * len(ims)), 'black')
                for i, im in enumerate(ims):
                    sheet.paste(im.convert('RGB'), (0, i * h))
                sheet = sheet.resize((w // 2, h * len(ims) // 2))
                sheet.save(OUT / f'sheet_{name}.png')
                if VIDEO:
                    fd = OUT / f'frames_{name}'; fd.mkdir(exist_ok=True)
                    fps = int(os.environ.get('FPS', '60')); n = int(float(os.environ.get('SECS', '1.8')) * fps)
                    for i in range(n):
                        url = await pg.evaluate(f"frame({i / fps}, INFO)")
                        (fd / f'{i:04d}.png').write_bytes(base64.b64decode(url.split(',')[1]))
                    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', str(fps), '-i', str(fd / '%04d.png'), '-c:v', 'libx264',
                                    '-pix_fmt', 'yuv420p', '-crf', '18', str(OUT / f'Treffer-{name}.mp4')], check=True)
            await b.close()
    finally:
        srv.terminate()
    print('errors:', errors or 'none')

asyncio.run(main())
