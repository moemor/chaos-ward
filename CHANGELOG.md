# 📝 Changelog

All notable changes to Chaos Ward. Versions follow `major.minor.patch`.

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
