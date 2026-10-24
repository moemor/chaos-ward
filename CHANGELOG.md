# 📝 Changelog

All notable changes to Chaos Ward. Versions follow `major.minor.patch`.

## 8.3.0 (October 2026)
* 🔬 Read log: with diagnostics on, every F6 compares the text recognition with the copied item and writes one line to `Diagnose\lesetest.txt` (how many mods were read right, which filter, how long, and which values were wrong). This makes it possible to improve recognition from real games.
* 🎯 Clicks that are not on your item (walking, clicking the stash, another item) no longer count as an orb and no longer lock or trigger a read. Chaos Ward remembers where the item was when you pressed F6. Moved the item? Hover it and press F6 again.
* 🧹 The orb counter in the sidebar box is gone; the box only shows the guard state and the on/off button. The counts stay on the Tracker page.
* 🕘 New **Recent** page: your last 60 copied or price-checked items with picture, rarity colour, source (F6, Ctrl+C or Exiled Exchange 2), time and mods. Uniques show their price from our list and jump to the Uniques page; other items open their item type on the Chaos page. A Trade button searches the item on the official trade site.
* 🪄 One-click setup for Exiled Exchange 2 in the settings: a small checklist (installed, running, keys don't clash, linked) and one button. Already installed: links it right away and starts it. Not installed yet: opens the official download page and links itself as soon as the install is finished.
* 🔗 Optional link with Exiled Exchange 2: when you check a price there (its key, Ctrl+D by default), Chaos Ward keeps that item in Recent. It only watches the key and reads the clipboard; it never presses Exiled Exchange 2's keys. Off by default (Settings → Exiled Exchange 2).
* 🤝 Works next to **Exiled Exchange 2** (the popular price check tool): Settings shows whether it is installed and running and which key does the price check, can start it together with Chaos Ward, and warns if your guard key is also used there. The Help page lists its price check key. Chaos Ward never presses Exiled Exchange 2's keys; both simply run side by side.
* ⌨️ **F6 copies the item for you.** Hover the item, press F6: Chaos Ward copies it (one Ctrl+C, no game action) and only turns on if an item was really copied. No item under the mouse, mouse not over the game, or a click in progress: the guard stays off with a short message, and your old clipboard comes back.
* 🔕 Only the keys you really need are on: F6. Reading your own Ctrl+C (the old way) and the Ctrl+Shift+P item protection key are now switches in the settings, off by default. Ctrl+Shift+P also copies the hovered item itself now. The Help page only lists keys that are switched on.
* 🖼️ Pictures from the game: "Pick mods" is now called **Chaos** and shows the Chaos Orb, Mageblood and Divine show their item next to the title, and every item type in the list shows a matching base item (for example the STR helmet for Armour, the DEX helmet for Evasion, tablets, relics, jewels and so on). The pictures come with the app, so they also work offline.
* 🔒 README: clarified that Chaos Ward only downloads from its own GitHub repository (game data and prices) and sends no data about you.
* 💎 New **Uniques** page: every priced unique per season (league) with its current price, the corruption enchants it can get (from the game data) and buttons that open the official trade site already filtered: normal, corrupted, twice corrupted, or corrupted with one specific enchant. Tick the enchants you want, Ctrl+C your unique, and Chaos Ward blocks your click when one of them appears while corrupting. Prices come from the poe.ninja economy API through our own daily list on GitHub (as poe.ninja asks), so the app never queries poe.ninja itself. Few listings = no price shown, because such prices are often fake.
* 🖼️ Every unique shows its item picture (from GGG's image server), small in the list and large in the detail view.
* 🐛 Mageblood hits found by reading the tooltip now also show "Mageblood" and Divine Orbs (before only the test showed that).
* 🐛 Item protection: fixed a hidden bug with the saved base type.
* 📦 **Game data updates**: Settings → Game data shows which patch your mod list is for. "Check for updates" looks on GitHub for a newer patch, "Download" fetches and checks it and only switches when the new list is complete; if anything fails you stay on your current patch. Older patches stay installed so you can switch back. New weapon types in a patch get their own list automatically. Optional: check on start (only looks, never downloads by itself).
* 🔍 Better text reading: typical OCR mix-ups in the game font (c/o, i/l, n/h and so on) count less, mods that wrap onto two lines in the tooltip are recognised, and when two reads disagree on a number Chaos Ward still decides if both lead to the same result. Fewer "not read reliably".
* 🏝️ The Island got a mode button: switch between Automatic and Pause right in game. Size and colour follow your settings.
* 🖥️ Start with Windows (Settings → App, or the tray menu). Chaos Ward then waits quietly in the tray.
* 📐 Overlay size (80 to 150 %) and overlay opacity (50 to 100 %) for Island, messages, item display and hit bar.
* 🎨 Choose your hit colour: gold, ember, crimson, violet or ice.
* 🪟 The main window remembers its size and position.
* ⌨️ New key overview on the Help page.
* 📏 Divine hit display: each value sits centred in its own box of equal size, with thin row lines.
* 💱 Market reader is now marked **Beta** and off by default (turn it on under Settings). Hover the ratio and hold Alt. Numbers are read in greyscale first (the orb icons next to them disturbed the old read), a wider area is searched when the lists are not right at the mouse, and a detailed log is written when diagnostics are on.
* 🏷️ Hit bar: long mods shrink to fit instead of being cut off, ranges like (21-35) are left out, Mageblood hits say "Mageblood" and several hits no longer show a single tier.
* 🧹 In-game messages no longer use symbols the game font cannot draw.
* 🔮 Mageblood counts Divine Orbs (uniques are rolled with Divines): hit bar, tracker history and the counter in the sidebar. The sidebar counter follows the page you open.

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
