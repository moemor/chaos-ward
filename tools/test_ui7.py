"""UI-Test v7: alle Seiten im neuen Stil mit einem nachgebauten WebView-Host.
Aufruf: python3 test_ui7.py <Ausgabeordner>"""
import asyncio, json, subprocess, sys, time
from pathlib import Path
from playwright.async_api import async_playwright

APP = Path('/home/claude/app')
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else '/tmp/ui7'); OUT.mkdir(parents=True, exist_ok=True)
FAKE = """
window.__sent = [];
const listeners = [];
window.chrome = window.chrome || {};
window.chrome.webview = { postMessage: m => window.__sent.push(m), addEventListener: (t, fn) => listeners.push(fn) };
window.__host = data => listeners.forEach(fn => fn({ data }));
"""
L = ["Amethyst","Basalt","Bismuth","Diamond","Gold","Granite","Jade","Quicksilver","Ruby","Sapphire","Silver","Stibnite","Sulphur","Topaz"]
DV = {"item": "Vortex Weaver  ·  Chiming Staff", "any": 0, "lines": [
  {"key": "gainofdamageasextracolddamage", "text": "Gain 29% of Damage as Extra Cold Damage", "nums": [{"v": 29, "lo": 21, "hi": 35}]},
  {"key": "increasedspelldamage", "text": "169% increased Spell Damage", "nums": [{"v": 169, "lo": 150, "hi": 179}]},
  {"key": "tomaximummana", "text": "+319 to maximum Mana", "nums": [{"v": 319, "lo": 271, "hi": 329}]},
  {"key": "increasedmanaregenerationrate", "text": "91% increased Mana Regeneration Rate", "nums": [{"v": 91, "lo": "", "hi": ""}]},
  {"key": "increasedlightradius", "text": "5% increased Light Radius", "nums": [{"v": 5, "lo": 5, "hi": 5}]},
  {"key": "addscolddamage", "text": "Adds 18 to 31 Cold Damage", "nums": [{"v": 18, "lo": 15, "hi": 22}, {"v": 31, "lo": 26, "hi": 36}]}],
  "rules": {"increasedspelldamage": {"1": {"op": ">=", "val": 172}}, "tomaximummana": {"1": {"op": ">=", "val": 315}}}}
STATE = {"type": "state", "lang": "de", "theme": "obsidian", "mode": 3, "pauseMs": 800, "shiftOnly": 1, "itemOverlay": 1, "island": 1, "market": 1,
         "autoDetect": 1, "sound": 1, "ignoreFractured": 1, "unsureRelease": 0, "streamVisible": 1, "volume": 70, "diag": 1, "learned": 3,
         "key": "F6", "keys": ["F2","F3","F4","F5","F6","F7"], "activeCat": "boots_dex_armour", "on": 1, "hit": 0,
         "wishes": {}, "need": {}, "rules": "# test\nMovement Speed >= 30", "ver": "8.1.0", "installed": 1,
         "mb": {"rules": {"Ruby": 2, "Sapphire": 1}, "any": 0, "eff": 40, "ban": ["Basalt","Granite"], "dup": 1}, "legacies": L,
         "soundName": "seal", "soundCustom": "", "hitBarSecs": 5, "ee2": {"found": 1, "running": 0, "path": "C:/x/Exiled Exchange 2.exe", "price": "Ctrl + D", "conflict": ""}, "ocr": {"best": 1215, "last": "6 Zeilen", "lang": "en-US", "en": 1}, "dv": DV}
STATS = {"type": "stats", "session": 137, "total": 4821, "since": 23, "dvSession": 31, "dvTotal": 212, "dvSince": 9, "cur": "c", "history": [
  {"t": "21.10. 15:40", "name": "Eagle Branch  ·  Dueling Wand", "orbs": 58},
  {"t": "21.10. 15:02", "name": "Doom Stride  ·  Velour Shoes", "orbs": 121},
  {"t": "20.10. 22:11", "name": "Mageblood  ·  Heavy Belt", "orbs": 340},
  {"t": "20.10. 21:37", "name": "Vortex Weaver  ·  Chiming Staff", "orbs": 12, "kind": "d"}]}
SYS = {"type": "sys", "items": [[1,"Windows","Windows 11 (10.0.22631)"],[1,"Oberfläche","WebView2 ✓"],[1,"Texterkennung","bereit · Englisch installiert"],
  [1,"Bildschirm","2560×1440 auf Monitor 2 von 2 · Anzeigen ×1.33"],[1,"Spiel","gefunden (PathOfExileSteam.exe)"],
  [-1,"Rechte","Spiel läuft als Administrator, Chaos Ward nicht → Klick-Sperre wirkt NICHT.","admin"],[1,"Anzeigemodus","Fenster-Vollbild ✓"],[0,"Spielsprache","noch kein Item kopiert"]]}


async def main():
    srv = subprocess.Popen([sys.executable, '-m', 'http.server', '8767', '-d', str(APP)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1)
    errors, fails = [], []
    def check(cond, what):
        if not cond: fails.append(what)
    try:
        async with async_playwright() as p:
            b = await p.chromium.launch()
            for vw, vh, tag in [(1180, 780, ''), (960, 620, '_small')]:
                pg = await b.new_page(viewport={'width': vw, 'height': vh})
                pg.on('pageerror', lambda e: errors.append(str(e)))
                pg.on('console', lambda m: m.type == 'error' and errors.append(m.text))
                await pg.add_init_script(FAKE)
                # Item-Bilder kommen im echten Programm vom GGG-Bilder-Server; hier ohne Internet ein Platzhalter
                from PIL import Image as _I; import io as _io
                _b = _io.BytesIO(); _I.new('RGBA', (94, 47), (170, 120, 60, 255)).save(_b, 'PNG'); _png = _b.getvalue()
                await pg.route('https://web.poecdn.com/**', lambda r: r.fulfill(status=200, content_type='image/png', body=_png))
                await pg.goto('http://localhost:8767/ui/index.html')
                await pg.wait_for_function("window.__sent.includes('ready')", timeout=10000)
                gids = await pg.evaluate("DB.byId['boots_dex_armour'].gids")
                st = dict(STATE); st['wishes'] = {"boots_dex_armour": {gids[0]: "", gids[1]: "T2", gids[5]: 25}}
                await pg.evaluate(f"window.__host({json.dumps(json.dumps(st))})")
                await pg.evaluate(f"window.__host({json.dumps(STATS)})")
                await pg.wait_for_timeout(400)
                await pg.screenshot(path=str(OUT / f'1_mods{tag}.png'))
                if tag:
                    for pid in ['pMb', 'pDv', 'pStats', 'pSet', 'pHelp']:
                        await pg.click(f'nav button[data-page="{pid}"]'); await pg.wait_for_timeout(150)
                        await pg.screenshot(path=str(OUT / f'{pid}{tag}.png'))
                    # kein waagrechtes Scrollen
                    over = await pg.evaluate("document.documentElement.scrollWidth > innerWidth")
                    check(not over, 'horizontal overflow at 960')
                    await pg.close(); continue

                # --- Mods: Haken, Tier-Klick, Stopp-Regel ---
                rows = await pg.query_selector_all('.mod')
                check(len(rows) > 10, 'mod rows rendered')
                await rows[3].click()
                await pg.click(f'.mod[data-gid="{gids[2]}"] [data-tier="2"]') if False else None
                first = await pg.query_selector('.mod:not(.on)')
                gid = await first.get_attribute('data-gid')
                await pg.click(f'.mod[data-gid="{gid}"] [data-tier="1"]')
                await pg.click('#stopSeg button[data-v="n"]'); await pg.click('#needPlus')
                await pg.wait_for_timeout(150)
                await pg.screenshot(path=str(OUT / '2_mods_interaction.png'))
                hunt_n = await pg.evaluate("document.querySelectorAll('#hunt li').length")
                check(hunt_n == 5, f'hunt list 5 entries (got {hunt_n})')
                gone = await pg.evaluate("!document.querySelector('#gReel')")
                check(gone, 'orb counter removed from the sidebar')
                await pg.fill('#search', 'life'); await pg.wait_for_timeout(100)
                n_life = len(await pg.query_selector_all('.mod'))
                await pg.fill('#search', '')
                await pg.click('#chips [data-f="sel"]'); await pg.wait_for_timeout(100)
                n_sel = len(await pg.query_selector_all('.mod'))
                check(n_sel == 5, f'selected filter 5 (got {n_sel})')
                await pg.click('#chips [data-f="all"]')
                await pg.fill('#catSearch', 'ring'); await pg.wait_for_timeout(100)
                await pg.screenshot(path=str(OUT / '3_catsearch.png'))
                await pg.fill('#catSearch', '')

                # --- Status: Treffer ---
                await pg.evaluate("window.__host(JSON.stringify({type:'status', on:1, hit:1}))"); await pg.wait_for_timeout(100)
                await pg.screenshot(path=str(OUT / '4_hit_state.png'), clip={'x': 0, 'y': 480, 'width': 230, 'height': 300})
                await pg.evaluate("window.__host(JSON.stringify({type:'status', on:0, hit:0}))")

                # --- Mageblood ---
                await pg.click('nav button[data-page="pMb"]'); await pg.wait_for_timeout(150)
                await pg.screenshot(path=str(OUT / '5_mb_want.png'))
                await pg.click('.leg[data-leg="Jade"] button[data-d="1"]')
                await pg.click('.leg[data-leg="Gold"] button[data-d="1"]')   # 5. Platz -> abgelehnt
                slots = await pg.evaluate("document.querySelectorAll('#slots .slot.f').length")
                check(slots == 4, f'mb 4 slots filled (got {slots})')
                await pg.click('#mbSeg button[data-v="ban"]'); await pg.click('.leg[data-leg="Topaz"]'); await pg.wait_for_timeout(100)
                await pg.screenshot(path=str(OUT / '6_mb_ban.png'))
                await pg.click('#mbSeg button[data-v="want"]'); await pg.click('#anyPlus'); await pg.click('#mbDupSw')

                # --- Divine ---
                await pg.click('nav button[data-page="pDv"]'); await pg.wait_for_timeout(150)
                await pg.screenshot(path=str(OUT / '7_divine.png'))
                await pg.click('.dn[data-k="gainofdamageasextracolddamage"] [data-act="tog"]')
                await pg.click('.dn[data-k="tomaximummana"] [data-act="op"]')
                await pg.fill('.dn[data-k="increasedspelldamage"] input[type=number]', '175')
                await pg.press('.dn[data-k="increasedspelldamage"] input[type=number]', 'Enter')
                await pg.click('[data-top="0.9"]'); await pg.wait_for_timeout(100)
                await pg.click('#dvAnySeg button[data-v="1"]')
                await pg.screenshot(path=str(OUT / '8_divine_set.png'))
                full = await pg.evaluate("document.querySelector('#dvMain').scrollHeight")
                await pg.evaluate("window.__host({type:'dv',dv:{item:'',any:0,lines:[],rules:{}}})"); await pg.wait_for_timeout(100)
                await pg.screenshot(path=str(OUT / '9_divine_empty.png'))
                await pg.click('[data-dvtake]')

                # --- Tracker ---
                # Item-Schutz-Liste
                await pg.evaluate("""window.__host(JSON.stringify({type:'prot', items:[{name:'Doom Stride', base:'Velour Shoes'}]}))""")
                await pg.click('nav button[data-page="pSet"]'); await pg.wait_for_timeout(100)
                await pg.click('[data-prot="Doom Stride"]'); await pg.wait_for_timeout(50)
                sent = await pg.evaluate("JSON.stringify(window.__sent.slice(-1))")
                check('protRemove' in sent, f'prot remove sent (got {sent})')
                await pg.evaluate("document.querySelector('#protList').scrollIntoView()"); await pg.wait_for_timeout(50)
                await pg.screenshot(path=str(OUT / '16_prot.png'))
                # eigene Taste aufnehmen
                await pg.click('nav button[data-page="pSet"]'); await pg.wait_for_timeout(100)
                await pg.select_option('#keySel', '__rec'); await pg.keyboard.press('Control+g'); await pg.wait_for_timeout(100)
                sent = await pg.evaluate("JSON.stringify(window.__sent.slice(-3))")
                check('^g' in sent, f'custom key ^g sent (got {sent})')
                await pg.select_option('#keySel', '__rec'); await pg.keyboard.press('g'); await pg.keyboard.press('Escape'); await pg.wait_for_timeout(100)
                sent = await pg.evaluate("JSON.stringify(window.__sent.slice(-2))")
                check('"g"' not in sent, f'plain letter refused (got {sent})')
                await pg.click('nav button[data-page="pStats"]'); await pg.wait_for_timeout(150)
                await pg.screenshot(path=str(OUT / '10_tracker.png'))
                bars = await pg.evaluate("document.querySelectorAll('#chart i').length")
                check(bars == 3, f'chaos chart bars 3 (got {bars})')
                await pg.click('#trkSeg button[data-k="d"]'); await pg.wait_for_timeout(150)
                await pg.screenshot(path=str(OUT / '10b_tracker_dv.png'))
                bars = await pg.evaluate("document.querySelectorAll('#chart i').length")
                check(bars == 1, f'divine chart bars 1 (got {bars})')
                tot = await pg.evaluate("document.querySelector('#stTotal').textContent")
                check(tot == '212', f'divine total 212 (got {tot})')
                await pg.click('#trkSeg button[data-k="c"]')

                # --- Einstellungen ---
                await pg.click('nav button[data-page="pSet"]')
                await pg.evaluate(f"window.__host({json.dumps(SYS)})"); await pg.wait_for_timeout(150)
                await pg.screenshot(path=str(OUT / '11_settings.png'))
                await pg.evaluate("document.querySelector('#pSet .set').scrollTop=2000"); await pg.wait_for_timeout(100)
                await pg.screenshot(path=str(OUT / '12_settings_bottom.png'))
                await pg.evaluate("document.querySelector('#pSet .set').scrollTop=0")
                await pg.click('.opt[data-mode="1"]'); await pg.click('#pauses [data-p="1500"]')
                await pg.click('.sw[data-k="sound"]')
                await pg.select_option('#sndSel', 'coin')
                await pg.click('#hbSecs [data-s="0"]'); await pg.click('#testHit'); await pg.click('#testHitDv2')
                await pg.click('#placeStart'); await pg.click('#ocrReset'); await pg.click('[data-act=admin]')
                await pg.click('#ovSize [data-s="130"]'); await pg.click('#accent [data-a="violet"]'); await pg.click('.sw[data-k="autostart"]')
                await pg.wait_for_timeout(100)
                sent = await pg.evaluate("JSON.stringify(window.__sent.slice(-3))")
                check('OvSize' in sent and 'Accent' in sent and 'Autostart' in sent, f'new settings sent (got {sent})')
                hitc = await pg.evaluate("getComputedStyle(document.documentElement).getPropertyValue('--hit').trim()")
                check(hitc.lower() == '#9a7eeb', f'accent applied (got {hitc})')
                await pg.evaluate("document.querySelector('#ovSize').scrollIntoView({block:'center'})"); await pg.wait_for_timeout(80)
                await pg.screenshot(path=str(OUT / '17_overlay_opts.png'))
                await pg.click('#langSeg button[data-l="en"]'); await pg.wait_for_timeout(150)
                await pg.screenshot(path=str(OUT / '13_settings_en.png'))

                # --- Hilfe ---
                await pg.click('nav button[data-page="pHelp"]'); await pg.wait_for_timeout(150)
                await pg.screenshot(path=str(OUT / '14_help_en.png'))
                # --- Spieldaten (Patch) ---
                await pg.click('nav button[data-page="pSet"]')
                await pg.evaluate("""window.__host(JSON.stringify({type:'data', cur:'0.5.5.4.2', groups:774, cats:72, busy:0, ok:1, msg:'Neuer Patch 0.6.0.1 verfügbar.', path:'../Mods.tsv',
                  local:[{ver:'0.5.5.4.2', bundled:1}], remote:[{ver:'0.6.0.1', date:'2026-12-12', groups:801, cats:77, have:0},{ver:'0.5.5.4.2', date:'2026-10-24', groups:774, cats:72, have:1}]}))""")
                await pg.wait_for_timeout(100)
                await pg.evaluate("document.querySelector('#dataPanel').scrollIntoView({block:'center'})"); await pg.wait_for_timeout(80)
                await pg.screenshot(path=str(OUT / '18_data.png'))
                dot = await pg.evaluate("document.querySelector('nav button[data-page=pSet]').classList.contains('dot')")
                check(dot, 'update dot on settings')
                await pg.click('[data-get="0.6.0.1"]'); await pg.wait_for_timeout(50)
                sent = await pg.evaluate("JSON.stringify(window.__sent.slice(-1))")
                check('dataGet' in sent and '0.6.0.1' in sent, f'dataGet sent (got {sent})')
                await pg.evaluate("""window.__host(JSON.stringify({type:'data', cur:'0.5.5.4.2', groups:774, cats:72, busy:0, ok:0, msg:'Download abgebrochen. Du bleibst auf Patch 0.5.5.4.2.', path:'../Mods.tsv',
                  local:[{ver:'0.5.5.4.2', bundled:1}], remote:[{ver:'0.6.0.1', date:'2026-12-12', groups:801, cats:77, have:0}]}))""")
                await pg.wait_for_timeout(100)
                await pg.screenshot(path=str(OUT / '19_data_fail.png'))
                await pg.click('nav button[data-page="pHelp"]'); await pg.wait_for_timeout(100)
                # --- Uniques ---
                await pg.click('nav button[data-page="pUq"]')
                await pg.evaluate("""window.__host(JSON.stringify({type:'uq', files:[{league:'Forbidden Rites', path:'../Uniques.tsv', date:'2026-10-24'}], cur:'../Uniques.tsv', msg:'', busy:0,
                  sel:{name:'Andvarius', base:'Gold Ring', wish:['(10-15)% increased Rarity of Items found']}}))""")
                await pg.wait_for_timeout(500)
                nrows = await pg.evaluate("document.querySelectorAll('.uqrow').length")
                check(nrows > 300, f'unique rows (got {nrows})')
                await pg.fill('#uqSearch', 'andvarius'); await pg.wait_for_timeout(100)
                await pg.click('.uqrow'); await pg.wait_for_timeout(100)
                await pg.screenshot(path=str(OUT / '20_uniques.png'))
                ne = await pg.evaluate("document.querySelectorAll('.ench').length"); non = await pg.evaluate("document.querySelectorAll('.ench.on').length")
                check(ne >= 8 and non == 1, f'enchants {ne} wished {non}')
                nimg = await pg.evaluate("document.querySelectorAll('.uqrow img').length"); big = await pg.evaluate("document.querySelectorAll('.uqbig img').length")
                check(nimg >= 1 and big == 1, f'unique images row {nimg} big {big}')
                await pg.click('[data-trade="twice"]'); await pg.wait_for_timeout(50)
                sent = await pg.evaluate("window.__sent.slice(-1)[0]")
                check('trade2/search/poe2/Forbidden%20Rites' in sent and 'twice_corrupted' in sent.replace('%22','"'), f'trade url (got {sent[:160]})')
                await pg.click('.ench:not(.on)'); await pg.wait_for_timeout(50)
                sent = await pg.evaluate("window.__sent.slice(-1)[0]")
                check(sent.startswith('uqWish'), f'uqWish sent (got {sent[:80]})')
                await pg.fill('#uqSearch', ''); await pg.select_option('#uqCats', 'Belt'); await pg.wait_for_timeout(100)
                await pg.screenshot(path=str(OUT / '21_uniques_belts.png'))
                # --- Verlauf ---
                await pg.evaluate("""window.__host(JSON.stringify({type:'recent', items:[
                  {t:'24.10. 21:50', src:'ee2', rarity:'Unique', name:'Mageblood', base:'Utility Belt', cat:'belt_belts', cls:'Belts', mods:['+1 to Maximum Charges','Legacy of Ruby']},
                  {t:'24.10. 21:41', src:'key', rarity:'Rare', name:'Doom Stride', base:'Velour Shoes', cat:'boots_dex_armour', cls:'Boots', mods:['30% increased Movement Speed','+85 to maximum Life']},
                  {t:'24.10. 21:30', src:'copy', rarity:'Magic', name:'Hale Gold Ring of the Whelpling', base:'Gold Ring', cat:'jewellery_rings', cls:'Rings', mods:[]}]}))""")
                await pg.click('nav button[data-page="pRec"]'); await pg.wait_for_timeout(200)
                await pg.click('.rec[data-i="1"] [data-act="mods"]'); await pg.wait_for_timeout(80)
                await pg.screenshot(path=str(OUT / '23_recent.png'))
                nrec = await pg.evaluate("document.querySelectorAll('.rec').length")
                check(nrec == 3, f'recent entries 3 (got {nrec})')
                await pg.click('.rec[data-i="0"] [data-act="trade"]'); await pg.wait_for_timeout(50)
                sent = await pg.evaluate("window.__sent.slice(-1)[0]")
                check('Mageblood' in sent and 'trade2' in sent, f'recent trade (got {sent[:120]})')
                await pg.click('.rec[data-i="1"] [data-act="chaos"]'); await pg.wait_for_timeout(100)
                act = await pg.evaluate("document.querySelector('.cat.on') && document.querySelector('.cat.on').dataset.cat")
                check(act == 'boots_dex_armour', f'recent opens chaos cat (got {act})')
                nk = await pg.evaluate("document.querySelectorAll('#keys kbd').length")
                check(nk == 4, f'key list only active keys + EE2: 4 (got {nk})')
                await pg.click('nav button[data-page="pMods"]'); await pg.wait_for_timeout(150)
                await pg.screenshot(path=str(OUT / '15_mods_en.png'))
                sent = await pg.evaluate("window.__sent")
                await pg.close()
            await b.close()
    finally:
        srv.terminate()
    print('rows "life":', n_life)
    for m in sent: print('   ', m.replace('\x1f', ' | ')[:120])
    print('errors:', errors or 'none')
    print('fails:', fails or 'none')

asyncio.run(main())
