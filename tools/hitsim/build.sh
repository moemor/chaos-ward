#!/bin/sh
# übersetzt die Zeichen-Funktionen der Treffer-Leiste aus dem AHK-Skript nach scene.js
cd "$(dirname "$0")" && python3 ../ahk2js.py /home/claude/app/PoE2-CraftSchutz.ahk scene.js DrawHitScene HitLand HitEase HitBack HitRnd HitReelMods HitReelDigits HitCrest HitTitleFit HitTitlePath HitTitle GoldCell Coin CheckMark DrawRayLayer SoftGlow Star Brush PenOf RectF RoundPath HitGfxSetup DrawText HitFontObj ReelMake HitReelReady HitSubText ShortMod ReelDv ReelDvTest DvLabel DvUnit NumStr MbHitSub DvLineHasRule HitCacheGet HitPanelDraw && node --check scene.js
