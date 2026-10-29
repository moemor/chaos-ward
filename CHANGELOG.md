# 📝 Changelog

All notable changes to Chaos Ward. Versions follow `major.minor.patch`.

## 8.3.0 (October 2026)

### New
* 🔎 New **Regex** page: search texts for the in-game search box, built from the mod list. Tabs for vendors (campaign shopping), items in your stash (item type, item level, quality, sockets), waystones (tier, quantity, rarity, pack size and more, mods, corrupted, delirious), tablets and relics. Pick mods, set a minimum value, copy, paste in game. Every search can be saved by name per tab. Chaos Ward only puts the text on your clipboard, you paste it yourself.
* 🔎 **Regex menu in game** with your saved search texts: hover a group (Vendor, Items, Waystones, Tablets, Relics), click a search to copy it, then Ctrl+V. Four ways to open it, each its own switch in Settings: a click on the magnifier of the vendor search box (recognised by picture, trained on real screenshots), a click into the search box (vendor, stash, relic locker, recognised by its text), Ctrl+F, and an optional "Regex" button on the Island. The menu never takes focus from the game and closes by itself.
* 🗑️ Regex, saved searches: each one shows its search text and has its own Copy and Delete buttons. A deleted search can be brought back with "Undo" for a few seconds, and the in-game menu forgets it right away. Searches saved in other tabs are listed with a link to their tab.
* 🧩 Regex page: mods are split by where they come from: normal mods, Breach tree (caster item, minion item), desecrated mods (crafted only by desecration, for example the Abyss mods on waystones and the Amanamu, Ulaman and Kurgal mods on gear) and the Breach mods from the Altered Collarbone. Picked mods carry a small tag with their source. Each mod has one simple checkbox (the whole row is clickable), and the rows are a bit larger.
* 🗂️ Regex, tab Items: mods are sorted into sections per item type (Jewels, Jewellery, Belt, Helmets, ...) with a picture and the number of mods. Mods that exist on several item types appear in each of their sections, ticked once means ticked everywhere. Sections open with a click, a search opens all matching ones.
* 📈 New **Market** page: Currency Exchange prices per league, sorted into Currency, Fragments, Abyss, Uncut Gems, Lineage Gems, Essences, Soul Cores, Idols, Runes, Omens, Expedition, Delirium, Breach and Verisium. Each row shows the price, how much was traded, a 7-day trend line and the change in percent. Prices in Divine, Exalted or Chaos, or Auto (Divine from 1 Divine up, Exalted below; very cheap items as "12 ↔ 1"). The header shows the Divine rate. Favourites with the star, a search over everything, sorting by any column. Rarely traded items are greyed out because their price is uncertain. Prices come from the poe.ninja economy API through our own list on GitHub, refreshed every hour; the page loads the new list by itself when it is older than 30 minutes (never while the guard is on).
* 🧮 Market **calculator**: click a row, type an amount, and see what it is worth in Divine, Exalted and Chaos.
* 🕘 Recent: currency, omens, runes and other exchange items show their market price.
* 🎨 **Five themes** (Settings → Look & language): Obsidian, Graphite, Midnight, Ember and Frost (light). The window title bar follows the theme.
* 🖼️ Uniques: the large item picture now always fits its box (long weapons no longer reach into the name), scaled up to at most twice its size so it stays sharp.
* 🧭 The pages are now called **Chaos Ward** and **Divine Ward** in the sidebar. The content area sits as its own rounded card next to the sidebar, so the two are clearly apart; the window title bar takes the sidebar colour.
* ✨ Calmer look: softer dividing lines, rounded panels, list rows and switches, smooth hover changes, and no focus frame after a mouse click.
* ⚙️ **Settings in tabs**: Guard, Display & hits, Regex, Reading & diagnostics, Game data & updates, Exiled Exchange 2, Look & language. The last tab you used is remembered.
* 🧾 Uniques: **current listings** from the official trade site on click (cheapest or most expensive first): price, age, corrupted or twice corrupted, the corruption enchant and all values, plus a button that copies the buy whisper. The price line now explains what the poe.ninja price means (rough market price from the cheaper listings, not sales).
* 🏝️ Island and the Ctrl+F Regex menu in the new style (soft surface, pill buttons, count badges, "click = copy" hint) and in the colours of your theme, light with Frost. Switchable under Look & language ("Island and Regex menu in the app theme"). Feedback sounds get their own volume slider and a test button.
* 🔢 Values and ranges in mod texts in a calmer steel blue instead of bright violet, and about 15 % more contrast for secondary text and lines in every theme.
* ⏳ Every action that loads shows a spinner in its button; messages are coloured (green = worked, red = failed, the red one shakes) and play a short sound (can be switched off under Look & language).
* 📊 Tracker in more detail: fewest and most orbs for a hit, median, orbs spent at market price, a bar for the current attempt compared with your average, bars coloured by luck and every hit compared with the average.
* 🩸 Mageblood page in the new style: cards, round steppers, clearer slots.
* 🔎 Regex: new tab **Saved** with every saved search of every tab (copy, edit, delete, undo), a tidier search text box, and clear messages when saving or copying.
* 📈 Market: the Divine / Exalted / Chaos rate as a clean box, larger secondary text.
* 🩹 Fixed: downloading a new patch always failed with "incomplete or damaged" because the checksum skipped the first bytes of the file. Patch 0.5.5.5 (flails, one and two hand axes and swords) is now also built in, with pictures for the new weapon types.
* 💬 Clearer update messages: after "Update prices" you are told whether newer prices were loaded or whether these already are the newest on GitHub (with their age). Market: the price currency buttons have a label ("Prices in") and confirm the switch.
* 🔴 The dot on Settings now also sits on the right tab (Game data & updates), Settings opens right there, and a banner offers "Download now" for a new patch. Opening Settings also checks for new game data.
* 🔒 Hit display, Island and Regex menu in the new style: rounded corners, soft edges instead of grey lines, the progress line follows the rounded panel, a hint of gold after the lock. In-game messages get rounded corners on Windows 11.
* ⏱️ Prices on GitHub are now updated about every hour for real: GitHub starts scheduled runs only every few hours, so each scheduled run now does several hourly rounds.
* 🟢 **You always see if an update worked**: next to "Update prices" (Market, Uniques) and under Game data a small status shows a spinner while loading, then a green dot "Up to date · checked 5 min ago", yellow "Outdated" or red "Failed" with the reason. The button reacts at once ("Loading …"), and a coloured message confirms the result of every update you start yourself. Failed background updates are shown too.
* 🔄 **Keeps itself up to date** (for example when a new league starts): with "Keep everything up to date" on, Chaos Ward downloads, checks and uses a new mod list by itself, refreshes unique prices (older than 12 hours) and market prices (older than 1 hour) on start and every 20 minutes when you are not in the game, and shows "New version" in the sidebar when a newer Chaos Ward is out. Never while the guard is on. A new league becomes the selected one automatically. On GitHub, market prices are updated every hour, unique prices every 6 hours and right away for a new league.
* 💎 New **Uniques** page: every priced unique per season (league) with its current price, the corruption enchants it can get (from the game data) and buttons that open the official trade site already filtered: normal, corrupted, twice corrupted, or corrupted with one specific enchant. Tick the enchants you want, hover your unique and press F6, and Chaos Ward blocks your click when one of them appears while corrupting. Prices come from the poe.ninja economy API through our own daily list on GitHub (as poe.ninja asks), so the app never queries poe.ninja itself. Few listings = no price shown, because such prices are often fake.
* 🖼️ Every unique shows its item picture (from GGG's image server), small in the list and large in the detail view.
* 🕘 New **Recent** page: your last 60 copied or price-checked items with picture, rarity colour, source (F6, Ctrl+C or Exiled Exchange 2), time and mods. Uniques show their price from our list and jump to the Uniques page; other items open their item type on the Chaos page. A Trade button searches the item on the official trade site.
* 📦 **Game data updates**: Settings → Game data shows which patch your mod list is for. "Check for updates" looks on GitHub for a newer patch, "Download" fetches and checks it and only switches when the new list is complete; if anything fails you stay on your current patch. Older patches stay installed so you can switch back. New weapon types in a patch get their own list automatically. Optional: check on start (only looks, never downloads by itself).
* 🌀 **Breach tree mods** on the Chaos page for rings, amulets and belts, in two sections: mods a caster item from the Breach tree can roll (for example +1 to Level of all Spell Skills on rings) and mods a minion item can roll (for example +1 to +2 Level of all Minion Skills on belts). A Chaos Orb can roll these on Breach tree items, and Chaos Ward can stop on them.
* 🩸 **Desecrated mods** (Amanamu, Ulaman, Kurgal and the special Breach mods from the Altered Collarbone) are now known to Chaos Ward: the Divine page shows their full range (no more "range unknown"), and the tooltip reading recognises them. They stay off the Chaos page, because a Chaos Orb never rolls them.
* 🪄 One-click setup for Exiled Exchange 2 in the settings: a small checklist (installed, running, keys don't clash, linked) and one button. Already installed: links it right away and starts it. Not installed yet: opens the official download page and links itself as soon as the install is finished.
* 🔗 Optional link with Exiled Exchange 2: when you check a price there (its key, Ctrl+D by default), Chaos Ward keeps that item in Recent. It only watches the key and reads the clipboard; it never presses Exiled Exchange 2's keys. Off by default (Settings → Exiled Exchange 2).
* 🤝 Works next to **Exiled Exchange 2** (the popular price check tool): Settings shows whether it is installed and running and which key does the price check, can start it together with Chaos Ward, and warns if your guard key is also used there. The Help page lists its price check key. Chaos Ward never presses Exiled Exchange 2's keys; both simply run side by side.
* ⌨️ **F6 copies the item for you.** Hover the item, press F6: Chaos Ward copies it (one Ctrl+C, no game action) and only turns on if an item was really copied. No item under the mouse, mouse not over the game, or a click in progress: the guard stays off with a short message, and your old clipboard comes back.

### Better
* 🔁 Locked because a read was unsure ("Couldn't read it reliably", "No change detected")? Hover the item and press F6 once: Chaos Ward copies it, checks it and unlocks or shows the hit. F6 away from the item still turns the guard off.
* 🔍 Better text reading: typical OCR mix-ups in the game font (c/o, i/l, n/h and so on) count less, mods that wrap onto two lines in the tooltip are recognised, and when two reads disagree on a number Chaos Ward still decides if both lead to the same result. Fewer "not read reliably".
* 🔬 Read log: with diagnostics on, every F6 compares the text recognition with the copied item and writes one line to `Diagnose\lesetest.txt` (how many mods were read right, which filter, how long, and which values were wrong). This makes it possible to improve recognition from real games.
* 🎯 Clicks that are not on your item (walking, clicking the stash, another item) no longer count as an orb and no longer lock or trigger a read. Chaos Ward remembers where the item was when you pressed F6. Moved the item? Hover it and press F6 again.
* 💎 Uniques: sort by price, wanted first, most listings or name (remembered). Uniques with few listings move to the end instead of mixing in. The search also finds categories. Prices older than 3 days get a hint to update. If you tick an enchant on a different unique, the page tells you which guarded unique it replaces.
* 🖼️ Recent: currency, omens, runes, soul cores, gems, waystones, fragments and similar items now show their picture too (about 1,600 small pictures from the game files, offline).
* 🕘 Recent: copying the same item again while crafting updates its entry instead of adding a new one.
* 🖼️ Pictures from the game: "Pick mods" is now called **Chaos** and shows the Chaos Orb, Mageblood and Divine show their item next to the title, and every item type in the list shows a matching base item (for example the STR helmet for Armour, the DEX helmet for Evasion, tablets, relics, jewels and so on). The pictures come with the app, so they also work offline.
* 🔕 Only the keys you really need are on: F6. Reading your own Ctrl+C (the old way) and the Ctrl+Shift+P item protection key are now switches in the settings, off by default. Ctrl+Shift+P also copies the hovered item itself now. The Help page only lists keys that are switched on.
* 🏝️ The Island got a mode button: switch between Automatic and Pause right in game. Size and colour follow your settings.
* 🖥️ Start with Windows (Settings → App, or the tray menu). Chaos Ward then waits quietly in the tray.
* 📐 Overlay size (80 to 150 %) and overlay opacity (50 to 100 %) for Island, messages, item display and hit bar.
* 🎨 Choose your hit colour: gold, ember, crimson, violet or ice.
* 🪟 The main window remembers its size and position.
* ⌨️ New key overview on the Help page.
* 📏 Divine hit display: each value sits centred in its own box of equal size, with thin row lines.
* 🏷️ Hit bar: long mods shrink to fit instead of being cut off, ranges like (21-35) are left out, Mageblood hits say "Mageblood" and several hits no longer show a single tier.
* 🗑️ The market reader (Currency Exchange) is removed. It never read the exchange reliably, so it is gone instead of staying a switch that does nothing.
* 🤝 Exiled Exchange 2 status (installed, running, keys, version) refreshes whenever you open Settings or Help. Versions older than 0.15.8 get a warning, because their price check fails on the trade site ("t.replace is not a function").
* 🔕 The "I keep running next to the clock" notice shows only the very first time you close the window.
* 🧹 The orb counter in the sidebar box is gone; the box only shows the guard state and the on/off button. The counts stay on the Tracker page.
* 🔮 Mageblood counts Divine Orbs (uniques are rolled with Divines): hit bar and tracker history.
* 🧾 Hints that still said Ctrl+C now name your guard key, and up to 10 tier marks fit on one line on the Chaos page.
* 🏷️ Windows now shows **Chaos Ward** instead of "AutoHotkey 64-bit" in the taskbar, the volume mixer and Task Manager (new version info in `ChaosWard.exe`; an old cached name is cleared on start).
* 🛡️ The Chaos Ward window always uses the seal icon in the taskbar and Alt+Tab, no more green AutoHotkey "H". Chaos Ward now has its own app ID, so Windows notifications show its name and seal too, and the setup refreshes the Windows icon cache.
* ✨ Polish: Settings in two tidy columns with a separate "Regex menu in game" panel, prices and counts in your language's number format (13,7 div, 10.000×), unique names in the game's unique colour everywhere, value ranges highlighted the same way on every page, Help lists Ctrl+F and the Regex page.
* 🔐 Security review: all bundled third-party parts checked against their sources (AutoHotkey, thqby ahk2_lib, Descolada OCR, Microsoft WebView2 loader). Safer clean-up: the setup only removes its own temp folder, uninstalling also removes the autostart entry, the diagnostic ZIP no longer uses a PowerShell policy override, and the GitHub Action uses a pinned checkout version.

### Fixed
* 🧮 Mod ranges that the game data lists backwards, like (15-10)% reduced, now show the right way round.
* 🐛 Mageblood hits found by reading the tooltip now also show "Mageblood" and Divine Orbs (before only the test showed that).
* 🐛 Item protection: fixed a hidden bug with the saved base type.
* 🧹 In-game messages no longer use symbols the game font cannot draw.
* 🔒 README: clarified that Chaos Ward only downloads from its own GitHub repository (game data and prices) and sends no data about you.

## 8.2.0 (October 2026)
* 🔐 New **Item protection** (prototype): Ctrl+C on a finished item, then Ctrl+Shift+P. Clicks on it are blocked (no stray orb, no accidental selling). Hold Alt to click anyway. List and on/off switch under Settings.
* 🖼️ The program, taskbar and desktop icon is now the seal.
* 🎯 Ctrl+C on an item always jumps to its item type on the Pick mods page, even when you already had another type open.
* 🧹 The "Smart" guard mode is gone. There are now two modes: Simple and Automatic (old "Smart" settings switch to Automatic).
* ⌨️ Record your own guard key: any key with Ctrl/Alt/Shift, the numpad, or mouse buttons 3, 4 and 5.
* 🔊 Four new hit sounds: Gong, Crystal, Harp, Drum.
* 💱 New **Market reader** (prototype): hover the rate list in the Currency Exchange. Chaos Ward reads both lists ("Available" and "Competing"), shows the spread, the absolute gap per unit, which ratio to set, the last gold fee for that pair (read from above "Place Order") and how the pair changed since you last looked. It only speaks up loudly when a pair is really worth it.

## 8.1.0 (October 2026)
* 🔤 New font Overpass. Small labels are no longer written in capitals and numbers no longer use a typewriter font.
* 🔢 Simpler orb counter in the sidebar: one big number instead of digit boxes.
* 📊 Tracker counts Chaos Orbs and Divine Orbs separately (switch at the top of the Tracker page).
* 🏝️ New **Island**: a small see-through seal at the top of the game. Hover it for quick access (open Chaos Ward, guard on/off). Can be moved and turned off.
* 🔕 With the Island on, the "Chaos Ward ON/OFF" message is gone: the seal shows the state (coloured ring, dimmed when off) and pulses when you switch.
* 🧪 Test button on the Mods and Mageblood pages (Divine already had one), plus a Mageblood test in the settings.

## 8.0.1 (October 2026)
* 🐛 A wished mod that looks similar to another mod on the item (for example "increased Spell Damage" when the item has "increased Cold Damage") no longer makes every read "not read reliably".
* ⚡ Faster decisions: when three reads in a row agree, Chaos Ward stops reading again. The whole screen is only read when the tooltip was not found at all.

## 8.0.0 (October 2026)
* 🎨 New look "Seal": one font family (IBM Plex), calm charcoal and stone, square shapes and one set of line icons.
* 🎯 Colours now mean something: teal = picked or guard on, gold only for a hit, red = banned or error.
* 🔒 New logo and a new hit display: the seal's notches light up, the lock turns and clicks shut, then everything stays still. No more slot machine, coins or sparkles.
* 🔊 New sound "Seal", timed to the lock. Old "Slot machine" settings switch to it automatically.
* 🔍 The in-game item display and messages use the same style.
* ⚡ The hit bar stops drawing once it stands still, so it costs nothing while it stays on screen.
* 🧹 Removed the Ko-fi support button and links.

## 7.4.2 (October 2026)
* 🏷️ Author name is now moemor everywhere (app, license, setup).

## 7.4.1 (October 2026)
* 🐛 Setup failed with "Script file not found. /setup". The installer and the uninstall entry now name the script explicitly.

## 7.4 (October 2026)
* 👀 Automatic mode waits until the tooltip has visibly changed before reading it. This is faster than a fixed delay and never reads the old tooltip after a click.
* 🧮 Values that are impossible for a mod (for example a lost or extra digit) are treated as a misread and read again instead of being trusted.
* 🐛 Mods whose tier ranges are listed in reverse in the game data (for example "(10-5)% reduced ...") now get the right tier.
* 🧰 The diagnostic package now also contains statistics of the change detection.

## 7.3.1 (October 2026)
* ☕ Support button on the Help page (Ko-fi).

## 7.3 (October 2026)
* 🧭 Correct positions on multi monitor setups with different Windows scaling (overlays, mouse and text recognition now all use real pixels).
* 🧰 New **Diagnostic package** button: one ZIP file on the desktop with system check, monitors, settings and unsure readings.
* The system check shows the scaling of the game monitor.

## 7.2 (October 2026)
* 📦 One file installer `ChaosWard-Setup.exe`, installs per user without admin rights.
* Entry under **Windows Settings → Apps** for uninstalling.

## 7.1.1 (October 2026)
* 📜 License (PolyForm Noncommercial 1.0.0) and copyright notice in the app.

## 7.1 (October 2026)
* 🐢➡️⚡ Smoother hit animation: fixed 30 frames per second (20 on slow PCs), expensive parts are drawn once and reused.

## 7.0.2 (October 2026)
* ⏩ New setting **Hit animation: Slot machine / Instant**.

## 7.0.1 (October 2026)
* 🐛 Fixed an error at the end of the hit bar ("Integer has no property Checked").

## 7.0 (October 2026)
* 🎨 Completely new look: slate and Path of Exile gold, new fonts and icons, game style item tooltip cards.
* 🎰 Slot machine hits: a reel locks onto the mod that hit, Divine shows digit reels with the reached values.
* 🔊 New sound "Slot machine", timed to the reel.
* 🔍 In game item display in tooltip style with tier chips.
* 📊 Tracker with a small chart of orbs per hit.

## 6.x (October 2026)
* ✨ Divine tab: thresholds for every number of an item, own hit display.
* 🩸 Mageblood: unwanted Legacies and "any duplicate is a hit".
* 🖥️ Support for many setups: multiple monitors, 1080p to 4K, ultrawide, HDR and SDR, system check.
* 🧠 Text recognition reads coloured mod text without HDR (colour channel filter).
* 🪟 Move in game windows, choice of hit sound, hit bar duration, re-calibrate text recognition.
