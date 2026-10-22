; ============================================================================
;  Chaos Ward  v7.4  (Craft-Schutz für Path of Exile 2)
;  Copyright (c) 2026 moemor - Lizenz: PolyForm Noncommercial 1.0.0 (siehe LIZENZ.txt)
;  Kein Verkauf / keine kommerzielle Nutzung ohne Erlaubnis.
;  Hilft beim Craften in Path of Exile 2:
;    - komplette Mod-Liste je Item-Art (wie poe2db), Wünsche einfach anhaken
;    - zeigt im Spiel die Mods eines Items mit Tier an und markiert Wünsche grün
;    - bremst/sperrt deine Klicks beim Spam-Craften, damit du nicht
;      "einmal zu viel" klickst und ein gutes Item wieder kaputt machst
;
;  SICHERHEIT (Bann-Schutz) - das Programm:
;    * liest NIEMALS den Speicher des Spiels
;    * drückt NIEMALS Tasten oder klickt für dich (kein Makro, keine Automatik)
;    * liest nur die Zwischenablage, nachdem DU selbst Strg+C gedrückt hast
;    * kann nur DEINE Klicks kurz zurückhalten (du machst also weniger, nie mehr)
;
;  Mod-Daten: Mods.tsv, erzeugt aus den Spieldaten (RePoE, repoe-fork/poe2)
; ============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
FileEncoding "UTF-8"
SetWorkingDir A_ScriptDir
#Include %A_ScriptDir%\lib\
#Include WebView2.ahk
#Include OCR.ahk
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
; Mehrere Monitore mit verschiedener Windows-Skalierung: überall echte Pixel verwenden
; (Maus, Monitor-Grenzen, Bildschirm-Ausschnitt der Texterkennung und Anzeigen passen dann zusammen)
try DllCall("SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")

global APP         := "Chaos Ward"
global APP_VER     := "8.0.0"
global APP_FILE    := "ChaosWard"
global INSTALL_DIR := EnvGet("LOCALAPPDATA") "\ChaosWard"
global OLD_DIR     := EnvGet("LOCALAPPDATA") "\PoE2-CraftSchutz"      ; alte Version (Craft-Schutz)
global LNK_NAME    := "Chaos Ward.lnk"
global INI         := A_ScriptDir "\Einstellungen.ini"
global WISH        := A_ScriptDir "\Wunschliste.txt"
global MODS_FILE   := A_ScriptDir "\Mods.tsv"
global HITS_FILE   := A_ScriptDir "\Treffer.txt"
global LEARN_FILE  := A_ScriptDir "\Gelernt.txt"
global DIAG_DIR    := A_ScriptDir "\Diagnose"
global DATA_DIR    := EnvGet("LOCALAPPDATA") "\ChaosWard\webdata"
global THEMES      := Map("obsidian", "121314")                         ; v8: ein Stil ("Siegel")
global PAUSES      := [300, 500, 800, 1000, 1500, 2000]
global PAUSE_NAMES := ["0,3 s", "0,5 s", "0,8 s", "1 s", "1,5 s", "2 s"]
global KEYS        := ["F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"]

; Farben v8 "Siegel": Kohle + Stein, Grünblau = gewählt / Schutz an, Gold NUR für Treffer, Rot = Fehler / verboten
global Clr := {Bg: "121314", Panel: "17181A", Panel2: "1E1F22", Field: "27292C", Line: "3A3D42"
    , Gold: "D6A640", Gold2: "F0CF7A", Text: "E7E3DB", Muted: "9A968E", Dim: "66635D"
    , Ward: "4FAE9B", Ward2: "8AD4C3", WardDark: "1B3631"
    , Green: "4FAE9B", GreenDark: "1B3631", Red: "D4604E", RedDark: "4A1F1A", Blue: "A3A8FF", Amber: "D98A3D"
    , Tip: "0E0F10", Slate: "121314", Band: "17181A", BandLine: "3A3D42", Rare: "E7E3DB", Magic: "A3A8FF", Sand: "9A968E"}

global St    := {On: false, Locked: false, Hit: false}
global Cfg   := {}
global Rules := []
global DB    := {Ver: "", Groups: Map(), Cats: [], CatById: Map(), Bases: []}
global Wishes := Map()        ; catId -> Map(gid -> Mindestwert oder "")
global NeedMap := Map()       ; catId -> Treffer ab
global CurKey := ""
global Banner := 0, ItemG := 0, MainGui := 0
global Ctl := {}
global Pages := [[], [], []], NavBtns := []
global ListRows := [], Filling := false, SelGid := "", ListFilter := "all"
global TvToCat := Map(), CatToTv := Map()
global TrayTipShown := false
global UI_MODE := "native", WV := 0, WVC := 0
global CopyTick := 0, LastItemTick := 0
global Track := {Active: false, Kind: "", Cat: "", Names: [], FracKeys: [], Expected: 0, Truth: Map(), LastSig: "", Thr: 1215, Alts: [1215, 1190, 200], Rect: 0}
global LEGACIES := ["Amethyst", "Basalt", "Bismuth", "Diamond", "Gold", "Granite", "Jade", "Quicksilver", "Ruby", "Sapphire", "Silver", "Stibnite", "Sulphur", "Topaz"]
global Mb := {Rules: Map(), Any: 0, Eff: "", Ban: Map(), Dup: 0}, MbMode := false
; Texterkennungs-Einstellungen: Zahl = Schwelle. Ab 1000 = "Farbkanal"-Filter (stärkster Kanal statt Helligkeit,
; liest farbige Schrift wie PoE-Blau auch ohne HDR voll hell), darunter = klassische Helligkeit.
global OCR_SETS := [1215, 1190, 1160, 200, 175, 225, 150, 130]
global OcrMaxMCode := 0, OcrLumMCode := 0
global ClickX := 0, ClickY := 0, OcrBusy := false
global Stats := {Session: 0, Total: 0, SinceHit: 0, History: []}
global TargetG := 0, TargetCtl := {}, LastItemName := "", PlaceGuis := Map()
global HitHits := 0, HitBarErr := "", HITBAR_SECS := [0, 3, 5, 10], OcrCalib := ""
global WatchSt := {N: 0, Hit: 0, TO: 0, Ms: 0}     ; Statistik der Änderungs-Erkennung (für das Diagnose-Paket)
global HitSurf := 0, HitBmps := Map()          ; HitBmps: zwischengespeicherte Teilbilder der Treffer-Leiste
global SOUNDS := ["seal", "hit", "chime", "coin", "ping", "windows", "custom"]
global FontsOk := false                         ; IBM Plex aus ui\fonts geladen?
global Dv := {Item: "", Lines: [], Rules: Map(), Any: 0}, CurPage := "", LastItemText := ""
global GameLang := ""                           ; Spielsprache laut letztem Strg+C: "", "en", "other"
global HitBarG := 0, HitBarT0 := 0, HitBarInfo := {Hits: 0, Orbs: 0}, HitBarPos := {X: 0, Y: 0, W: 0, H: 0}
global LastOcr := 0, Aliases := Map(), NumFixes := Map()

try TraySetIcon(A_ScriptDir "\ui\icon.ico")
LoadFonts()
LoadConfig()
if HasVal(A_Args, "/uninstall") {                ; aus Windows "Apps" -> Deinstallieren (#SingleInstance beendet ein laufendes Chaos Ward)
    Uninstall()
    ExitApp
}
MaybeInstall()
LoadDB()
LoadWishes()
EnsureWishlist()
LoadRules()
LoadStats()
LoadLearned()
LoadMb()
LoadDv()
BuildUI()
RegisterKey(Cfg.Key)
SetupTray()
OnClipboardChange(ClipChanged)
return

; ============================================================================
;  Klick-Sperre (nur aktiv, wenn das Spiel im Vordergrund ist)
; ============================================================================
#HotIf GuardReady()
~*LButton Up::OnClickUp()
#HotIf GuardLocked()
*LButton::return
*LButton Up::return
~*^c::OnCopyPressed()
#HotIf

GuardReady()  => St.On && !St.Locked && IsPoE()
GuardLocked() => St.On && St.Locked && IsPoE()
PoEHotIf(*)   => IsPoE()

IsPoE() {
    try {
        hwnd := WinActive("A")
        if !hwnd
            return false
        if WinGetClass(hwnd) = "POEWindowClass"
            return true
        return InStr(WinGetProcessName(hwnd), "PathOfExile") > 0
    }
    return false
}

OnClickUp() {
    if Cfg.ShiftOnly && !GetKeyState("Shift", "P")
        return
    St.Locked := true
    CountOrb(1)
    if Cfg.Mode = 1 {
        ShowBanner(T("bPause"), "", Clr.Amber)
        SetTimer(Unlock, -Cfg.PauseMs)
    } else if Cfg.Mode = 3 && Track.Active {
        global ClickX, ClickY
        MouseGetPos(&ClickX, &ClickY)
        HideItemNow()
        WatchStart()                            ; warten, bis sich der Tooltip sichtbar ändert, dann lesen
    } else if Cfg.Mode = 3 {
        ShowBanner(T("bStart"), T("bStartSub"), Clr.Blue)
    } else {
        ShowBanner(T("bCopy"), T("bCopySub"), Clr.Blue)
    }
}

Unlock() {
    if St.Hit || !St.On
        return
    St.Locked := false
    ShowOnBanner()
}

ToggleGuard(*) {
    SetTimer(Unlock, 0)
    if St.Hit {
        St.Hit := false
        St.Locked := false
        St.On := false
        HideHitBar()
    } else {
        St.On := !St.On
        St.Locked := false
    }
    if St.On {
        ShowOnBanner()
        SetTimer(CheckSetupOnStart, -300)       ; Admin / echtes Vollbild prüfen (einmal je Sitzung)
    } else {
        ShowBanner(T("bOff"), "", Clr.Dim)
        SetTimer(HideBanner, -1500)
        HideItem()
    }
    RefreshTarget()
    UpdateHeader()
}

ShowOnBanner() {
    SetTimer(HideBanner, 0)
    how := Cfg.ShiftOnly ? T("bShift") : T("bClick")
    ShowBanner(T("bOn"), how "   ·   " T("bOffKey"), Clr.Ward)
}

; reel = Walzen-Daten für die Treffer-Leiste (ReelFromItem / AutoEval / ReelDv), 0 = keine
TriggerHit(hits, style := "", sub := "", reel := 0) {
    global HitHits
    SetTimer(Unlock, 0)
    SetTimer(HideBanner, 0)
    St.Hit := true
    St.Locked := true                            ; Klick ist SOFORT gesperrt, die Show kommt danach
    HitHits := hits
    RecordHit()
    UpdateHeader()
    HideBanner()
    orbs := Stats.History.Length ? Stats.History[1].Orbs : 0
    if !ShowHitBar(hits, orbs, style, sub, reel) {   ; Treffer-Leiste im Spielautomaten-Stil (Divine: eigener Stil)
        ShowBanner(T("bHit"), StrReplace(T("bHitSub"), "{n}", hits) "`n[v" APP_VER " Notlösung: " HitBarErr "]", Clr.Red, true)
        PlayHitSound(false, style)
        return
    }
    HitSoundSynced(style)
}

; Sound passend zum Siegel: "Siegel" startet sofort (Kerben ticken, Schloss rastet genau mit dem Bild ein),
; alle anderen Sounds spielen im Moment des Einrastens
HitSoundSynced(style, force := false) {
    if Cfg.SoundName = "seal" || Cfg.HitAnim = "instant" {   ; "Sofort": Ton sofort (Siegel nur das Einrasten)
        PlayHitSound(force, style)
        return
    }
    if force
        SetTimer(() => PlayHitSound(true, style), -Round(HitLand(style) * 1000))
    else
        SetTimer(() => PlayHitSound(false, style), -Round(HitLand(style) * 1000))
}

PlayHitSound(force := false, style := "") {
    if (!Cfg.Sound && !force) || Cfg.Volume <= 0
        return
    v := Round(Cfg.Volume / 100 * 0xFFFF)
    try DllCall("winmm\waveOutSetVolume", "Ptr", 0, "UInt", v | (v << 16))   ; Lautstärke nur für Chaos Ward
    f := SoundFile(style)
    if f = "" {
        try SoundPlay("*48")                    ; Windows-Ton
    } else {
        try SoundPlay(f)
        catch
            try SoundPlay("*48")
    }
}

; eingebaute Sounds (ui\hit\*.wav, selbst erzeugt), Windows-Ton oder eigene Datei
SoundFile(style := "") {
    switch Cfg.SoundName {
        case "windows":
            return ""
        case "seal":                              ; Siegel: eigene Fassung für Chaos und Divine, "Sofort" ohne Anlauf
            f := A_ScriptDir "\ui\hit\seal_" (style = "dv" ? "dv" : "chaos") (Cfg.HitAnim = "instant" ? "_now" : "") ".wav"
            if FileExist(f)
                return f
        case "custom":
            if Cfg.SoundCustom != "" && FileExist(Cfg.SoundCustom)
                return Cfg.SoundCustom
        default:
            f := A_ScriptDir "\ui\hit\" Cfg.SoundName ".wav"
            if FileExist(f)
                return f
    }
    f := A_ScriptDir "\ui\hit\hit.wav"
    return FileExist(f) ? f : ""
}

; Schlau-Modus: Strg+C gedrückt, aber nichts kopiert? (z.B. weil Shift noch gehalten wird)
OnCopyPressed() {
    global CopyTick
    CopyTick := A_TickCount
    if Cfg.Mode >= 2 && !St.Hit
        SetTimer(CheckCopy, -900)
}

CheckCopy() {
    if St.On && St.Locked && !St.Hit && Cfg.Mode >= 2 && LastItemTick < CopyTick
        ShowBanner(T("bNoCopy"), T("bNoCopySub"), Clr.Amber)
}

; ============================================================================
;  Item lesen (nur Zwischenablage - nachdem DU Strg+C gedrückt hast)
; ============================================================================
ClipChanged(dataType) {
    global LastItemTick
    if dataType != 1 || !IsPoE()
        return
    try txt := A_Clipboard
    catch
        return
    if !CheckGameLang(txt)                       ; Spiel nicht auf Englisch -> klare Meldung statt stillem Nichts
        return
    item := ParseItem(txt)
    if !IsObject(item)
        return
    LastItemTick := A_TickCount
    global LastItemName, MbMode, LastItemText
    LastItemName := item.Name, LastItemText := txt
    if CurPage = "pDv" || DvActiveFor(item) {   ; Divine: Werte der vorhandenen Mods
        DvFlowSafe(item, CurPage = "pDv")
        return
    }
    if IsMageblood(item) {                       ; eigener Ablauf für Mageblood
        MbMode := true
        hits := EvaluateMB(item)
        if Cfg.Mode = 3
            StartTrackMB(item)
        RefreshTarget()
        WebPost(Map("type", "page", "id", "pMb"))
        if Cfg.ItemOverlay
            ShowItem(item, {Main: "Mageblood", Sub: "Mage's Legacy"}, hits, 1)
        if St.On && !St.Hit {
            if MbRuleCount() > 0 && hits >= 1
                TriggerHit(hits, "", "", ReelFromItem(item))
            else if St.Locked && Cfg.Mode >= 2
                Unlock()
        }
        return
    }
    if MbMode {
        MbMode := false
        RefreshTarget()
    }
    cat := 0
    if Cfg.AutoDetect
        cat := DetectCat(item)
    detected := IsObject(cat)
    if !detected && DB.CatById.Has(Cfg.ActiveCat)
        cat := DB.CatById[Cfg.ActiveCat]
    if detected && Cfg.ActiveCat != cat.Id
        SelectCat(cat.Id, true)
    need := IsObject(cat) ? GetNeed(cat.Id) : 1
    hits := Evaluate(item, cat)
    if Cfg.Mode = 3 && St.On && St.Locked && !St.Hit && Track.Active && IsObject(cat) && cat.Id = Track.Cat
        LearnFrom(item, cat)                     ; aus der Korrektur lernen
    if Cfg.Mode = 3
        StartTrack(item, cat)
    wishCount := IsObject(cat) ? GetWishes(cat.Id).Count + Rules.Length : Rules.Length
    if Cfg.ItemOverlay
        ShowItem(item, cat, hits, need)
    if St.On && !St.Hit {
        if wishCount > 0 && hits >= need
            TriggerHit(hits, "", "", ReelFromItem(item))
        else if St.Locked && Cfg.Mode >= 2
            Unlock()
    }
}

ParseItem(txt) {
    txt := StrReplace(txt, "`r", "")
    if !RegExMatch(txt, "m)^(Item Class|Gegenstandsklasse|Rarity|Seltenheit)\s*:")
        return 0
    sections := StrSplit(txt, "--------")
    nameLines := []
    for line in StrSplit(sections[1], "`n") {
        line := Trim(line)
        if line != "" && !InStr(line, ":")
            nameLines.Push(line)
    }
    name := ""
    for p in nameLines
        name .= (name = "" ? "" : "  ·  ") p
    item := {Name: name = "" ? "Item" : name, NameLines: nameLines, Mods: []}

    loop sections.Length {
        if A_Index = 1
            continue
        kind := "", skip := false
        for line in StrSplit(sections[A_Index], "`n") {
            line := Trim(line)
            if line = ""
                continue
            ; Kopfzeile aus Strg+Alt+C, z.B.  { Prefix Modifier "Hale" (Tier: 5) - Life }
            if SubStr(line, 1, 1) = "{" {
                kind := ""
                skip := RegExMatch(line, "i)implicit|implizit|rune|enchant|verzauber") > 0
                if RegExMatch(line, "i)(prefix|präfix)")
                    kind := "P"
                else if RegExMatch(line, "i)suffix")
                    kind := "S"
                continue
            }
            if skip
                continue
            if InStr(line, ": ") || SubStr(line, -1) = ":"
                continue
            if SubStr(line, 1, 1) = "(" && SubStr(line, -1) = ")"
                continue
            if RegExMatch(line, "i)\((implicit|implizit|rune|enchant|enchanted|verzaubert)\)")
                continue
            frac := RegExMatch(line, "i)\((fractured|gebrochen|zerbrochen)\)\s*$") > 0
            item.Mods.Push({Text: line, Norm: NormLine(line), Kind: kind, Hit: false, Tier: 0, Known: false, Fractured: frac})
        }
    }
    return item
}

NormLine(line) {
    line := RegExReplace(line, "\(\s*-?\d+(?:\.\d+)?\s*[-–]\s*-?\d+(?:\.\d+)?\s*\)", "")
    line := RegExReplace(line, "i)\s*\((crafted|desecrated|fractured|gebrochen|zerbrochen|augmented|enchanted|veiled|corrupted)\)\s*$", "")
    return Trim(line)
}

DetectCat(item) {
    i := item.NameLines.Length
    while i >= 1 {
        line := item.NameLines[i]
        for b in DB.Bases
            if InStr(line, b.Name, true)
                return DB.CatById.Has(b.Cat) ? DB.CatById[b.Cat] : 0
        i--
    }
    return 0
}

Evaluate(item, cat) {
    hits := 0
    if IsObject(cat) {
        w := GetWishes(cat.Id)
        for gid in cat.Gids {
            g := DB.Groups[gid]
            res := MatchGroup(g, item.Mods)
            if !IsObject(res)
                continue
            val := FirstNumber(res[1].Norm)
            tierN := TierOf(g, val)
            for gpi, m in res {
                m.Known := true
                m.GPart := gpi
                m.Gid := gid
                m.Val := val
                m.Tier := tierN
                if m.Kind = ""
                    m.Kind := g.Kind
            }
            ignored := false
            if Cfg.IgnoreFractured
                for m in res
                    if m.Fractured
                        ignored := true
            if w.Has(gid) && !ignored {
                mn := w[gid]
                if mn = ""
                    ok := true
                else if RegExMatch(mn, "^T(\d+)$", &tm)        ; Mindest-Tier: T1 bis Tn zählen
                    ok := tierN >= 1 && tierN <= Integer(tm[1])
                else
                    ok := val != "" && val >= mn
                if ok {
                    for m in res
                        m.Hit := true
                    hits++
                }
            }
        }
    }
    ; eigene Freitext-Wünsche (z.B. für den deutschen Spiel-Client)
    for mod in item.Mods {
        if mod.Hit || (Cfg.IgnoreFractured && mod.Fractured)
            continue
        for r in Rules {
            if !InStr(mod.Text, r.Text)
                continue
            if r.Op = "" || CompareOk(FirstNumber(mod.Norm), r.Op, r.Val) {
                mod.Hit := true
                hits++
                break
            }
        }
    }
    return hits
}

MatchGroup(g, mods) {
    for pat in g.Pats {
        found := []
        for rx in pat {
            hit := 0
            for m in mods {
                if RegExMatch(m.Norm, rx) {
                    hit := m
                    break
                }
            }
            if !hit
                break
            found.Push(hit)
        }
        if found.Length = pat.Length && found.Length > 0
            return found
    }
    return 0
}

TierOf(g, val) {
    if val = ""
        return 0
    for i, r in g.Ranges
        if IsObject(r) && val >= Min(r.Lo, r.Hi) && val <= Max(r.Lo, r.Hi)   ; auch verkehrte Bereiche wie (10-5)
            return i
    return 0
}

FirstNumber(text) {
    text := RegExReplace(text, "\(\s*-?[\d.,]+\s*[-–]\s*-?[\d.,]+\s*\)", "")
    if RegExMatch(text, "-?\d+(?:[.,]\d+)?", &m)
        return StrReplace(m[0], ",", ".") + 0
    return ""
}

CompareOk(num, op, val) {
    if num = ""
        return false
    return op = ">=" ? num >= val : num <= val
}

; ============================================================================
;  Anzeigen im Spiel (Overlay) - durchklickbar, klaut nie den Fokus
; ============================================================================
NewOverlay(bg := "") {
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000 -DPIScale")   ; echte Pixel, Größe regelt OvScale()
    g.BackColor := bg != "" ? bg : Clr.Slate
    if !Cfg.StreamVisible      ; sonst für Discord/OBS unsichtbar (und für die eigene Texterkennung)
        try DllCall("SetWindowDisplayAffinity", "Ptr", g.Hwnd, "UInt", 0x11)
    return g
}

; mitgelieferte Schriften nur für Chaos Ward laden (FR_PRIVATE: nichts wird in Windows installiert)
LoadFonts() {
    global FontsOk
    n := 0
    for f in ["IBMPlexSans-Regular", "IBMPlexSans-Medium", "IBMPlexSans-SemiBold", "IBMPlexSans-Bold"
            , "IBMPlexSansCondensed-Medium", "IBMPlexSansCondensed-SemiBold", "IBMPlexMono-Medium", "IBMPlexMono-SemiBold"] {
        p := A_ScriptDir "\ui\fonts\" f ".ttf"
        if FileExist(p)
            try n += DllCall("gdi32\AddFontResourceEx", "Str", p, "UInt", 0x10, "Ptr", 0) > 0
    }
    FontsOk := n >= 6
}

; Schrift für die Anzeigen: IBM Plex (eine Familie), sonst Segoe UI.
;  face: "" = Plex Sans (Stärke aus opts: w400/w500/w600/w700), "cond" = Plex Sans Condensed, "mono" = Plex Mono.
;  Windows kennt die Zwischenstärken nur unter eigenem Namen ("IBM Plex Sans SemiBold"), daher die Umsetzung hier.
;  Text mit Zeichen, die Plex nicht hat (✔ 🔒 ...), bleibt in Segoe UI (Windows ergänzt dort fehlende Zeichen)
OvFont(g, opts, face := "", text := "") {
    g.SetFont(opts, "Segoe UI")
    if !FontsOk || RegExMatch(text, "[^\x{20}-\x{17F}\x{2013}-\x{2026}\x{2039}\x{203A}\x{20AC}\x{201E}\x{2212}\x{2265}\x{2264}\x{00D7}\n\r\t]")
        return
    w := RegExMatch(opts, "\bw(\d+)", &m) ? Integer(m[1]) : 400
    fam := face = "cond" ? "IBM Plex Sans Condensed" : face = "mono" ? "IBM Plex Mono" : "IBM Plex Sans"
    if face = "cond" || face = "mono"
        fam .= w >= 600 ? " SemiBold" : " Medium", w := 400
    else if w = 500 || w = 600
        fam .= w = 500 ? " Medium" : " SemiBold", w := 400
    g.SetFont(RegExReplace(opts, "\bw\d+", "w" w), fam)
}

; 1-px-Rahmen (normale Fenster haben keinen); nach dem Anzeigen mit OvFrameFit einpassen
OvFrame(g, col) {
    fr := []
    loop 4
        fr.Push(g.AddText("x0 y0 w1 h1 Background" col))
    return fr
}
OvFrameFit(fr, w, h) {
    fr[1].Move(0, 0, w, 1), fr[2].Move(0, h - 1, w, 1), fr[3].Move(0, 0, 1, h), fr[4].Move(w - 1, 0, 1, h)
}

ShowOverlay(g, x, y, alpha, posKey := "", fixW := 0, fixH := 0) {
    g.Show(fixW ? "Hide w" fixW " h" fixH : "Hide AutoSize")
    g.GetPos(, , &gw, &gh)
    m := GameMon()
    if posKey != "" && (pt := PosAnchor(posKey)) {   ; vom Spieler verschoben
        x := posKey = "Item" ? pt.X - gw : pt.X - gw // 2
        y := pt.Y
    } else {
        y := m.T + OvPx(y)
        if x = "center"
            x := m.L + (m.W - gw) // 2
        else if x = "right"
            x := m.L + m.W - gw - OvPx(40)
        else
            x := m.L + OvPx(x)
    }
    x := Max(m.L, Min(m.L + m.W - gw, x)), y := Max(m.T, Min(m.T + m.H - gh, y))
    g.Show("NA x" x " y" y)
    try WinSetTransparent(alpha, "ahk_id " g.Hwnd)
    RoundCorners(g.Hwnd)
    return gh
}

; Meldung oben in der Mitte: Kohle-Fläche, Akzent als Kante oben, feiner Rahmen
ShowBanner(title, sub := "", accent := "", big := false) {
    global Banner
    if accent = ""
        accent := Clr.Ward
    old := Banner
    g := NewOverlay()
    g.MarginX := OvPx(big ? 36 : 24)
    g.MarginY := OvPx(big ? 18 : 11)
    fr := OvFrame(g, Clr.Line)
    bar := g.AddText("x0 y0 w10 h" OvPx(2) " Background" accent)
    if big
        OvFont(g, FS(24) " w600 c" accent, "cond", title)
    else
        OvFont(g, FS(12.5) " w600 c" Clr.Text, , title)
    t1 := g.AddText("xm ym Center +0x80", title)
    t2 := 0
    if sub != "" {
        OvFont(g, FS(big ? 12 : 10) " w400 c" Clr.Muted, , sub)
        t2 := g.AddText("xm y+" OvPx(2) " Center +0x80", sub)
    }
    t1.GetPos(, , &w1)
    w := w1
    if t2 {
        t2.GetPos(, , &w2)
        w := Max(w1, w2)
        t2.Move(, , w)
    }
    t1.Move(, , w)
    h := ShowOverlay(g, "center", big ? 140 : 30, big ? 245 : 238, "Banner")
    g.GetPos(, , &gw)
    bar.Move(, , gw)
    OvFrameFit(fr, gw, h)
    Banner := g
    if IsObject(old)
        old.Destroy()
}

HideBanner() {
    global Banner
    if IsObject(Banner)
        Banner.Destroy()
    Banner := 0
}

; Item-Anzeige im Stil "Siegel": Name + Art oben, Mods als Liste, Treffer in Gold, Tiers als kleine Marken
ShowItem(item, cat, hits, need) {
    global ItemG
    old := ItemG
    g := NewOverlay(Clr.Tip)
    g.MarginX := 0, g.MarginY := 0
    pad := OvPx(16), gap := OvPx(8)
    fr := OvFrame(g, Clr.Line)
    done := hits >= need && hits > 0
    topk := g.AddText("x0 y0 w1 h1 Background" (done ? Clr.Gold : Clr.Ward))     ; Kante oben: Grünblau, bei Treffer Gold
    hline := g.AddText("x0 y0 w1 h1 Background" Clr.Line)
    n1 := item.NameLines.Length ? item.NameLines[1] : item.Name, n2 := ""
    loop item.NameLines.Length - 1
        n2 .= (n2 = "" ? "" : "  ") item.NameLines[A_Index + 1]
    OvFont(g, FS(13) " w600 c" Clr.Text, , n1)
    h1 := g.AddText("x0 y0 +0x80", n1)
    head := [h1]
    if n2 != "" {
        OvFont(g, FS(10.5) " w500 c" Clr.Text, , n2)
        head.Push(g.AddText("x0 y0 +0x80", n2))
    }
    OvFont(g, FS(9.5) " w400 c" Clr.Muted)
    head.Push(g.AddText("x0 y0 +0x80", IsObject(cat) ? cat.Main " › " cat.Sub : T("oUnknown")))
    rows := []
    for mod in item.Mods {
        col := mod.Hit ? Clr.Gold2 : mod.Fractured ? Clr.Muted : Clr.Text
        mk := 0
        if mod.Hit {                              ; Haken aus Segoe UI Symbol (hat Plex nicht)
            g.SetFont(FS(10) " w700 c" Clr.Gold, "Segoe UI Symbol")
            mk := g.AddText("x0 y0 +0x80", "✔")
        }
        OvFont(g, FS(11) " " (mod.Hit ? "w600" : "w400") " c" col, , mod.Text)
        tx := g.AddText("x0 y0 +0x4080", mod.Text)           ; 0x4000 = zu lang -> "…"
        chip := 0
        lbl := (mod.Tier ? "T" mod.Tier : "") (mod.Fractured ? (mod.Tier ? " " : "") "FR" : "")
        if lbl != "" {
            kind := mod.Tier && (mod.Kind = "P" || mod.Kind = "S") ? " " mod.Kind : ""
            fg := mod.Hit ? "1A1406" : mod.Tier = 1 ? Clr.Ward2 : Clr.Muted
            bg := mod.Hit ? Clr.Gold : mod.Tier = 1 ? Clr.WardDark : Clr.Panel2
            OvFont(g, FS(8.5) " w600 c" fg, "mono", lbl kind)
            chip := g.AddText("x0 y0 Center +0x80 Background" bg, " " lbl kind " ")
        }
        rows.Push({T: tx, C: chip, M: mk})
    }
    if rows.Length = 0 {
        OvFont(g, FS(10.5) " w400 c" Clr.Muted)
        rows.Push({T: g.AddText("x0 y0 +0x80", T("oNoMods")), C: 0, M: 0})
    }
    fline := g.AddText("x0 y0 w1 h1 Background" Clr.Line)
    OvFont(g, FS(9.5) " " (done ? "w600 c" Clr.Gold2 : "w400 c" Clr.Muted))
    foot := g.AddText("x0 y0 +0x80", StrReplace(StrReplace(T("oHits"), "{n}", hits), "{m}", need))

    ; --- Maße: links bündig, Tiers rechts in einer Spalte
    W := OvPx(320), cmax := 0
    for c in head {
        c.GetPos(, , &cw)
        W := Max(W, cw + 2 * pad)
    }
    for r in rows {
        r.T.GetPos(, , &tw, &th), r.W := tw, r.H := th, r.CW := 0, r.CH := 0, r.MW := 0, r.MH := 0
        if r.C
            r.C.GetPos(, , &cw2, &ch2), r.CW := cw2, r.CH := ch2, cmax := Max(cmax, cw2)
        if r.M
            r.M.GetPos(, , &mw2, &mh2), r.MW := mw2 + OvPx(6), r.MH := mh2
    }
    mkW := 0
    for r in rows
        mkW := Max(mkW, r.MW)
    for r in rows
        W := Max(W, mkW + r.W + (cmax ? gap + cmax : 0) + 2 * pad)
    W := Min(W, OvPx(760))
    y := OvPx(12)
    for i, c in head {
        c.GetPos(, , , &ch)
        c.Move(pad, y, W - 2 * pad, ch)
        y += ch + (i < head.Length ? OvPx(1) : 0)
    }
    y += OvPx(10)
    topk.Move(0, 0, W, OvPx(2)), hline.Move(0, y, W, 1)
    y += OvPx(9)
    for r in rows {
        rw := Min(r.W, W - 2 * pad - mkW - (cmax ? gap + cmax : 0))
        x := pad
        if r.M
            r.M.Move(x, y + (r.H - r.MH) // 2)
        x += mkW
        r.T.Move(x, y, rw, r.H)
        if r.C
            r.C.Move(W - pad - r.CW, y + (r.H - r.CH) // 2)
        y += r.H + OvPx(3)
    }
    y += OvPx(7)
    fline.Move(0, y, W, 1)
    y += OvPx(7)
    foot.GetPos(, , , &fh)
    foot.Move(pad, y, W - 2 * pad, fh)
    H := y + fh + OvPx(8)
    ShowOverlay(g, "right", 120, 240, "Item", W, H)
    OvFrameFit(fr, W, H)
    ItemG := g
    if IsObject(old)
        old.Destroy()
    SetTimer(HideItem, St.Hit ? 0 : -8000)
}

HideItem() {
    global ItemG
    if St.Hit
        return
    if IsObject(ItemG)
        ItemG.Destroy()
    ItemG := 0
}

HideItemNow() {
    global ItemG
    if St.Hit
        return
    SetTimer(HideItem, 0)
    if IsObject(ItemG)
        ItemG.Destroy()
    ItemG := 0
}

RoundCorners(hwnd) {
    v := Buffer(4, 0), NumPut("Int", 1, v)          ; DWMWCP_DONOTROUND (Windows 11): kantig wie die App
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 33, "Ptr", v, "UInt", 4)
}

; ============================================================================
;  Hauptfenster
; ============================================================================
BuildMain() {
    global MainGui
    g := Gui("-MaximizeBox -Resize", APP)
    g.BackColor := Clr.Bg
    g.MarginX := 0, g.MarginY := 0
    MainGui := g

    ; ---------- Kopfzeile ----------
    g.AddText("x0 y0 w1110 h86 Background" Clr.Panel)
    g.AddText("x0 y86 w1110 h1 Background" Clr.Line)
    g.SetFont("s22 bold c" Clr.Gold2, "Segoe UI")
    g.AddText("x26 y12 BackgroundTrans", APP)
    g.SetFont("s9 norm c" Clr.Muted)
    g.AddText("x28 y54 w420 BackgroundTrans", "Version " APP_VER "   ·   Spieldaten " (DB.Ver = "" ? "?" : DB.Ver) "   ·   " DB.Groups.Count " Mod-Gruppen")
    g.SetFont("s10 bold")
    Ctl.Pill := g.AddText("x560 y30 w170 h28 Center +0x200", "")
    g.SetFont("s12 bold")
    Ctl.Toggle := MkBtn(g, "x746 y20 w340 h48", "", ToggleGuard)

    ; ---------- Reiter ----------
    names := ["  Mods wählen  ", "  Schutz-Einstellungen  ", "  Hilfe  "]
    x := 26
    for i, n in names {
        g.SetFont("s11 bold")
        b := g.AddText("x" x " y98 h34 +0x200 +0x100 Center Background" Clr.Bg, n)
        b.GetPos(, , &bw)
        b.Move(, , bw + 10)
        b.OnEvent("Click", ShowPage.Bind(i))
        NavBtns.Push(b)
        x += bw + 18
    }
    Ctl.NavLine := g.AddText("x26 y132 w10 h3 Background" Clr.Gold)
    g.AddText("x0 y135 w1110 h1 Background" Clr.Line)

    BuildPageMods(g)
    BuildPageGuard(g)
    BuildPageHelp(g)

    ; ---------- Fußzeile ----------
    g.SetFont("s9 norm c" Clr.Dim, "Segoe UI")
    g.AddText("x26 y710 w860", "Sicher: liest nie den Spielspeicher, drückt nie Tasten für dich. Liest nur, was DU mit Strg+C kopierst.")
    g.SetFont("s9 bold c" Clr.Green)
    Ctl.Saved := g.AddText("x900 y710 w190 Right", "")

    g.OnEvent("Close", OnMainClose)
    DarkTitle(g.Hwnd)
    ShowPage(1)
    UpdateHeader()
}

; ---------- Seite 1: Mods wählen ----------
BuildPageMods(g) {
    P := Pages[1]
    g.SetFont("s9 bold c" Clr.Muted, "Segoe UI")
    P.Push(g.AddText("x26 y152", "ITEM-ART"))
    g.SetFont("s10 norm c" Clr.Text)
    tv := g.AddTreeView("x26 y174 w250 h520 -E0x200 -Lines Background" Clr.Panel " c" Clr.Text)
    Dark(tv.Hwnd)
    Ctl.TV := tv
    P.Push(tv)
    lastMain := "", parent := 0
    for cat in DB.Cats {
        if cat.Main != lastMain {
            parent := tv.Add(cat.Main, 0, "Bold")
            lastMain := cat.Main
        }
        id := tv.Add(TreeLabel(cat), parent)
        TvToCat[id] := cat.Id
        CatToTv[cat.Id] := id
    }
    tv.OnEvent("ItemSelect", OnTreeSelect)

    ; Mitte: Liste
    g.SetFont("s15 bold c" Clr.Gold2)
    Ctl.CatTitle := g.AddText("x296 y148 w520 h30", "")
    P.Push(Ctl.CatTitle)
    P.Push(g.AddText("x296 y184 w520 h34 Background" Clr.Field))
    g.SetFont("s10 norm c" Clr.Text)
    Ctl.Search := DarkEdit(g.AddEdit("x306 y191 w500 h22 -E0x200"))
    SendMessage(0x1501, 1, StrPtr("Suchen ...  z.B.  Life,  Resistance,  Speed"), Ctl.Search.Hwnd)
    Ctl.Search.OnEvent("Change", (*) => SetTimer(FillList, -200))
    P.Push(Ctl.Search)

    Ctl.Filter := []
    x := 296
    for i, f in [["all", "Alle"], ["P", "Präfixe"], ["S", "Suffixe"], ["sel", "★ Gewählt"]] {
        g.SetFont("s9 bold")
        b := MkBtn(g, "x" x " y226 w92 h26", f[2], SetFilter.Bind(f[1]))
        b.Key := f[1]
        Ctl.Filter.Push(b)
        P.Push(b)
        x += 96
    }

    g.SetFont("s10 norm c" Clr.Text)
    lv := g.AddListView("x296 y260 w520 h434 -E0x200 Checked -Multi NoSortHdr Background" Clr.Panel " c" Clr.Text
        , ["Mod  (Bereich über alle Tiers)", "Art", "Tiers", "Min."])
    lv.ModifyCol(1, 330), lv.ModifyCol(2, 62), lv.ModifyCol(3, 50), lv.ModifyCol(4, 56)
    Dark(lv.Hwnd)
    try Dark(SendMessage(0x101F, 0, 0, lv.Hwnd), "DarkMode_ItemsView")   ; Spaltenkopf dunkel
    lv.OnEvent("ItemCheck", OnLVCheck)
    lv.OnEvent("ItemSelect", OnLVSelect)
    lv.OnEvent("DoubleClick", OnLVDouble)
    Ctl.LV := lv
    P.Push(lv)

    ; Rechts: Wunsch-Karte
    P.Push(g.AddText("x836 y148 w250 h546 Background" Clr.Panel))
    g.SetFont("s9 bold c" Clr.Muted)
    P.Push(g.AddText("x852 y162 w220 BackgroundTrans", "DEINE WÜNSCHE FÜR DIESES ITEM"))
    g.SetFont("s26 bold c" Clr.Gold2)
    Ctl.WishCount := g.AddText("x852 y180 w220 BackgroundTrans", "0")
    P.Push(Ctl.WishCount)
    g.SetFont("s9 norm c" Clr.Muted)
    P.Push(g.AddText("x852 y226 w220 BackgroundTrans", "Mods angehakt"))

    g.SetFont("s10 norm c" Clr.Text)
    P.Push(g.AddText("x852 y258 w220 BackgroundTrans", "TREFFER, wenn mindestens"))
    g.SetFont("s14 bold")
    P.Push(MkBtn(g, "x852 y282 w40 h34", "–", (*) => ChangeNeed(-1)))
    Ctl.Need := g.AddText("x896 y282 w60 h34 Center +0x200 Background" Clr.Field " c" Clr.Gold2, "1")
    P.Push(Ctl.Need)
    P.Push(MkBtn(g, "x960 y282 w40 h34", "+", (*) => ChangeNeed(1)))
    g.SetFont("s10 norm c" Clr.Text)
    P.Push(g.AddText("x852 y322 w220 BackgroundTrans", "davon auf dem Item sind."))

    P.Push(g.AddText("x852 y352 w220 h1 Background" Clr.Line))
    g.SetFont("s9 bold c" Clr.Muted)
    P.Push(g.AddText("x852 y362 w220 BackgroundTrans", "AUSGEWÄHLTER MOD"))
    g.SetFont("s10 bold c" Clr.Text)
    Ctl.SelName := g.AddText("x852 y382 w222 h40 BackgroundTrans", "Klick links auf einen Mod.")
    P.Push(Ctl.SelName)
    g.SetFont("s10 norm c" Clr.Text)
    P.Push(g.AddText("x852 y428 w120 BackgroundTrans", "Mindestens:"))
    Ctl.Min := DarkEdit(g.AddEdit("x960 y425 w80 h24 Number -E0x200"), Clr.Gold2)
    SendMessage(0x1501, 1, StrPtr("egal"), Ctl.Min.Hwnd)
    Ctl.Min.OnEvent("Change", OnMinChange)
    P.Push(Ctl.Min)
    g.SetFont("s9 norm c" Clr.Muted, "Consolas")
    Ctl.Tiers := g.AddText("x852 y458 w226 h196 BackgroundTrans", "")
    P.Push(Ctl.Tiers)
    g.SetFont("s9 bold", "Segoe UI")
    P.Push(MkBtn(g, "x852 y656 w222 h28", "Alle Häkchen hier entfernen", ClearWishes, "ghost"))

    SetFilter("all")
    if !DB.CatById.Has(Cfg.ActiveCat) && DB.Cats.Length
        Cfg.ActiveCat := DB.Cats[1].Id
    if DB.CatById.Has(Cfg.ActiveCat)
        SelectCat(Cfg.ActiveCat, true)
}

; ---------- Seite 2: Schutz-Einstellungen ----------
BuildPageGuard(g) {
    P := Pages[2]
    Card(g, P, 26, 152, 520, 250, "1.  WIE SOLL ICH DICH SCHÜTZEN?")
    Ctl.ModeBtns := []
    for i, m in [["EINFACH", "nach jedem Klick kurz Pause"], ["SCHLAU", "erst Strg+C, dann prüfe ich"]] {
        y := 186 + (i - 1) * 70
        g.SetFont("s12 bold")
        b := MkBtn(g, "x46 y" y " w480 h60", "", SetMode.Bind(i))
        b.Text := "   " m[1] "   ·   " m[2]
        Ctl.ModeBtns.Push(b)
        P.Push(b)
    }
    g.SetFont("s10 norm c" Clr.Text)
    P.Push(g.AddText("x46 y336 w200 BackgroundTrans", "Länge der Pause (Einfach):"))
    Ctl.PauseBtns := []
    x := 46
    for i, n in PAUSE_NAMES {
        g.SetFont("s9 bold")
        b := MkBtn(g, "x" x " y360 w74 h28", n, SetPause.Bind(i))
        Ctl.PauseBtns.Push(b)
        P.Push(b)
        x += 80
    }

    Card(g, P, 566, 152, 520, 250, "2.  EXTRAS")
    Ctl.Toggles := Map()
    y := 186
    for opt in [["ShiftOnly", "Nur bremsen, wenn ich Shift halte (Dauer-Craften)"]
            , ["ItemOverlay", "Bei Strg+C die Mods im Spiel anzeigen"]
            , ["AutoDetect", "Item-Art beim Strg+C automatisch erkennen"]
            , ["Sound", "Ton bei einem Treffer"]] {
        g.SetFont("s9 bold")
        pill := MkBtn(g, "x586 y" y " w54 h26", "", ToggleOpt.Bind(opt[1]))
        g.SetFont("s10 norm c" Clr.Text)
        lbl := g.AddText("x652 y" y + 3 " w420 +0x100 BackgroundTrans", opt[2])
        lbl.OnEvent("Click", ToggleOpt.Bind(opt[1]))
        Ctl.Toggles[opt[1]] := pill
        P.Push(pill), P.Push(lbl)
        y += 40
    }
    g.SetFont("s10 norm c" Clr.Text)
    P.Push(g.AddText("x586 y" y + 8 " w220 BackgroundTrans", "Taste zum An-/Ausschalten im Spiel:"))
    g.SetFont("s12 bold")
    P.Push(MkBtn(g, "x820 y" y + 2 " w34 h30", "‹", (*) => ChangeKey(-1)))
    Ctl.KeyLbl := g.AddText("x858 y" y + 2 " w70 h30 Center +0x200 Background" Clr.Field " c" Clr.Gold2, Cfg.Key)
    P.Push(Ctl.KeyLbl)
    P.Push(MkBtn(g, "x932 y" y + 2 " w34 h30", "›", (*) => ChangeKey(1)))

    Card(g, P, 26, 420, 1060, 274, "3.  EIGENE WÜNSCHE ALS TEXT  (optional - gelten für alle Items, z.B. für den deutschen Spiel-Client)")
    g.SetFont("s9 norm c" Clr.Muted)
    P.Push(g.AddText("x46 y450 w1020 BackgroundTrans", "Eine Zeile = ein Wunsch. Schreib ein Stück vom Text, wie er im Spiel steht.  Mit  >= 80  meinst du: mindestens 80.  Zeilen mit # werden ignoriert."))
    P.Push(g.AddText("x46 y474 w1020 h204 Background" Clr.Field))
    g.SetFont("s10 norm c" Clr.Text, "Consolas")
    Ctl.Wish := DarkEdit(g.AddEdit("x56 y480 w1004 h192 -E0x200 WantTab", FileRead(WISH, "UTF-8")))
    Dark(Ctl.Wish.Hwnd)
    Ctl.Wish.OnEvent("Change", (*) => SetTimer(SaveAll, -500))
    P.Push(Ctl.Wish)
    g.SetFont("s10 norm", "Segoe UI")
    UpdateGuardPage()
}

; ---------- Seite 3: Hilfe ----------
BuildPageHelp(g) {
    P := Pages[3]
    Card(g, P, 26, 152, 660, 542, "SO GEHT'S  -  IN 5 SCHRITTEN")
    steps := [
        ["Spiel vorbereiten", "Stell das Spiel auf 'Fenster-Vollbild' (Windowed Fullscreen). Sonst siehst du meine Anzeigen nicht."],
        ["Wünsche anhaken", "Reiter 'Mods wählen': links die Item-Art wählen, dann die Mods anhaken, die du willst. Tipp: Kopier dein Item im Spiel mit Strg+C - dann wähle ich die richtige Item-Art von selbst."],
        ["Schutz einschalten", "Im Spiel " Cfg.Key " drücken. Oben erscheint 'Chaos Ward AN'."],
        ["Craften", "Rechtsklick auf den Chaos Orb, Shift halten, aufs Item klicken. Einfach-Modus: nach jedem Klick kurz Pause. Schlau-Modus: nach jedem Klick Strg+C drücken."],
        ["TREFFER!", "Ist genug von deiner Wunschliste drauf, wird es rot: Klicken ist gesperrt, du kannst nicht drüberklicken. Mit " Cfg.Key " bist du fertig."]]
    y := 192
    for i, s in steps {
        g.SetFont("s14 bold c" Clr.Bg)
        P.Push(g.AddText("x50 y" y " w36 h36 Center +0x200 Background" Clr.Gold, i))
        g.SetFont("s11 bold c" Clr.Gold2)
        P.Push(g.AddText("x102 y" y - 2 " w560 BackgroundTrans", s[1]))
        g.SetFont("s10 norm c" Clr.Text)
        P.Push(g.AddText("x102 y" y + 22 " w560 h64 BackgroundTrans", s[2]))
        y += 98
    }
    Card(g, P, 706, 152, 380, 330, "GUT ZU WISSEN")
    g.SetFont("s10 norm c" Clr.Text)
    P.Push(g.AddText("x726 y188 w344 h280 BackgroundTrans",
        "• Strg+Alt+C zeigt im Spiel zusätzlich Präfix/Suffix an.`n`n"
        . "• Die Tiers (T1 = bestes) kommen aus den Spieldaten, wie bei poe2db.`n`n"
        . "• Die Mod-Liste ist englisch. Spielst du auf Deutsch, nutze 'Eigene Wünsche als Text'.`n`n"
        . "• Passiert gar nichts? Dann läuft das Spiel als Administrator - starte es normal.`n`n"
        . "• Strg+C geht nicht? Shift kurz loslassen."))
    Card(g, P, 706, 498, 380, 196, "SICHERHEIT")
    g.SetFont("s10 norm c" Clr.Text)
    P.Push(g.AddText("x726 y534 w344 h100 BackgroundTrans",
        "Kein Makro: Ich lese nie den Spielspeicher, drücke nie Tasten und klicke nie für dich. Ich lese nur, was du mit Strg+C kopierst, und halte höchstens deine Klicks kurz zurück."))
    if A_ScriptDir = INSTALL_DIR {
        g.SetFont("s9 bold")
        P.Push(MkBtn(g, "x726 y648 w170 h30", "Vom PC entfernen", Uninstall, "ghost"))
    }
}

Card(g, P, x, y, w, h, title) {
    P.Push(g.AddText("x" x " y" y " w" w " h" h " Background" Clr.Panel))
    P.Push(g.AddText("x" x " y" y " w4 h" h " Background" Clr.Gold))
    g.SetFont("s9 bold c" Clr.Muted, "Segoe UI")
    P.Push(g.AddText("x" x + 20 " y" y + 14 " w" w - 40 " BackgroundTrans", title))
}

; ---------- eigene Knöpfe (dunkel, flach) ----------
MkBtn(g, opts, text, fn, style := "normal") {
    b := g.AddText(opts " Center +0x200 +0x100 Background" Clr.Panel2 " c" Clr.Text, text)
    b.OnEvent("Click", fn)
    b.OnEvent("DoubleClick", fn)
    return b
}

Paint(b, bg, fg) {
    b.Opt("+Background" bg)
    b.SetFont("c" fg)
    b.Redraw()
}

ShowPage(n, *) {
    for i, list in Pages
        for c in list
            c.Visible := (i = n)
    for i, b in NavBtns
        Paint(b, Clr.Bg, i = n ? Clr.Gold2 : Clr.Muted)
    NavBtns[n].GetPos(&x, , &w)
    Ctl.NavLine.Move(x, , w)
    Ctl.NavLine.Redraw()
}

UpdateHeader() {
    if UI_MODE = "web" {
        PushStatus()
        return
    }
    if !IsObject(MainGui)
        return
    if St.Hit {
        Ctl.Pill.Text := "●  TREFFER!"
        Paint(Ctl.Pill, Clr.RedDark, "FFFFFF")
        Ctl.Toggle.Text := "FERTIG - SCHUTZ AUS   ·   " Cfg.Key
        Paint(Ctl.Toggle, Clr.Red, "FFFFFF")
    } else if St.On {
        Ctl.Pill.Text := "●  SCHUTZ IST AN"
        Paint(Ctl.Pill, Clr.GreenDark, Clr.Green)
        Ctl.Toggle.Text := "SCHUTZ AUSSCHALTEN   ·   " Cfg.Key
        Paint(Ctl.Toggle, Clr.Panel2, Clr.Text)
    } else {
        Ctl.Pill.Text := "●  SCHUTZ IST AUS"
        Paint(Ctl.Pill, Clr.Panel2, Clr.Muted)
        Ctl.Toggle.Text := "▶  SCHUTZ EINSCHALTEN   ·   " Cfg.Key
        Paint(Ctl.Toggle, Clr.Gold, Clr.Bg)
    }
}

UpdateGuardPage() {
    for i, b in Ctl.ModeBtns
        Paint(b, i = Cfg.Mode ? Clr.GreenDark : Clr.Panel2, i = Cfg.Mode ? Clr.Green : Clr.Muted)
    for i, b in Ctl.PauseBtns
        Paint(b, PAUSES[i] = Cfg.PauseMs ? Clr.Gold : Clr.Panel2, PAUSES[i] = Cfg.PauseMs ? Clr.Bg : Clr.Muted)
    for key, pill in Ctl.Toggles {
        on := Cfg.%key%
        pill.Text := on ? "AN" : "AUS"
        Paint(pill, on ? Clr.Green : Clr.Panel2, on ? Clr.Bg : Clr.Muted)
    }
    Ctl.KeyLbl.Text := Cfg.Key
}

SetMode(i, *) {
    Cfg.Mode := i
    UpdateGuardPage()
    SaveAll()
}

SetPause(i, *) {
    Cfg.PauseMs := PAUSES[i]
    UpdateGuardPage()
    SaveAll()
}

ToggleOpt(key, *) {
    Cfg.%key% := !Cfg.%key%
    UpdateGuardPage()
    SaveAll()
    if key = "ShiftOnly" && St.On && !St.Locked
        ShowOnBanner()
}

ChangeKey(d, *) {
    idx := 5
    for i, k in KEYS
        if k = Cfg.Key
            idx := i
    idx := Mod(idx - 1 + d + KEYS.Length, KEYS.Length) + 1
    Cfg.Key := KEYS[idx]
    RegisterKey(Cfg.Key)
    UpdateGuardPage()
    UpdateHeader()
    SaveAll()
}

; ---------- Mod-Liste ----------
CurCat() => DB.CatById.Has(Cfg.ActiveCat) ? DB.CatById[Cfg.ActiveCat] : 0

TreeLabel(cat) {
    n := GetWishes(cat.Id).Count
    return cat.Sub (n ? "    ★ " n : "")
}

OnTreeSelect(tv, item) {
    if TvToCat.Has(item) {
        if TvToCat[item] = Cfg.ActiveCat
            return
        SelectCat(TvToCat[item], false)
    } else if item {
        tv.Modify(item, "Expand")
        child := tv.GetChild(item)
        if child
            tv.Modify(child, "Select")
    }
}

SelectCat(catId, moveTree) {
    global SelGid
    if !DB.CatById.Has(catId)
        return
    if UI_MODE = "web" {
        Cfg.ActiveCat := catId
        WebPost(Map("type", "cat", "id", catId))
        SetTimer(SaveAll, -500)
        return
    }
    Cfg.ActiveCat := catId
    cat := DB.CatById[catId]
    if moveTree && CatToTv.Has(catId)
        Ctl.TV.Modify(CatToTv[catId], "Select Vis")
    Ctl.CatTitle.Text := cat.Main "  ›  " cat.Sub
    SelGid := ""
    FillList()
    UpdateSide()
    SetTimer(SaveAll, -500)
}

SetFilter(key, *) {
    global ListFilter
    ListFilter := key
    for b in Ctl.Filter
        Paint(b, b.Key = key ? Clr.Gold : Clr.Panel2, b.Key = key ? Clr.Bg : Clr.Muted)
    FillList()
}

FillList() {
    global ListRows, Filling
    cat := CurCat()
    lv := Ctl.LV
    Filling := true
    lv.Opt("-Redraw")
    lv.Delete()
    ListRows := []
    if IsObject(cat) {
        w := GetWishes(cat.Id)
        q := Trim(Ctl.Search.Value)
        for kind in ["P", "S"] {
            if (ListFilter = "P" || ListFilter = "S") && ListFilter != kind
                continue
            for gid in cat.Gids {
                g := DB.Groups[gid]
                if g.Kind != kind
                    continue
                wished := w.Has(gid)
                if ListFilter = "sel" && !wished
                    continue
                if q != "" && !InStr(g.Text, q)
                    continue
                mn := wished ? (w[gid] = "" ? "egal" : ">= " w[gid]) : ""
                lv.Add(wished ? "Check" : "", g.Text, kind = "P" ? "Präfix" : "Suffix", g.N, mn)
                ListRows.Push(gid)
            }
        }
    }
    lv.Opt("+Redraw")
    Filling := false
}

OnLVCheck(lv, row, checked) {
    if Filling || row < 1 || row > ListRows.Length
        return
    cat := CurCat()
    if !IsObject(cat)
        return
    gid := ListRows[row]
    w := GetWishes(cat.Id)
    if checked && !w.Has(gid)
        w[gid] := ""
    else if !checked && w.Has(gid)
        w.Delete(gid)
    lv.Modify(row, "Col4", checked ? (w[gid] = "" ? "egal" : ">= " w[gid]) : "")
    WishesChanged(cat)
    if gid = SelGid
        ShowSelected(gid)
}

OnLVSelect(lv, row, selected) {
    global SelGid
    if Filling || !selected || row < 1 || row > ListRows.Length
        return
    SelGid := ListRows[row]
    ShowSelected(SelGid)
}

OnLVDouble(lv, row) {
    if row < 1
        return
    checked := lv.GetNext(row - 1, "Checked") = row
    lv.Modify(row, checked ? "-Check" : "Check")
}

ShowSelected(gid) {
    global Filling
    g := DB.Groups[gid]
    Ctl.SelName.Text := g.Text
    w := GetWishes(Cfg.ActiveCat)
    Filling := true
    Ctl.Min.Value := w.Has(gid) ? w[gid] : ""
    Filling := false
    tierTxt := ""
    for line in StrSplit(g.TierTxt, ";;") {
        p := StrSplit(line, "~")
        if p.Length < 4
            continue
        n := Integer(SubStr(p[1], 2))
        r := (n >= 1 && n <= g.Ranges.Length) ? g.Ranges[n] : ""
        val := IsObject(r) ? (r.Lo = r.Hi ? r.Lo : r.Lo " - " r.Hi) : ""
        tierTxt := Format("{:-4}", p[1]) " ab Lvl " Format("{:-3}", p[2]) "  " val "`n" tierTxt
    }
    Ctl.Tiers.Text := "TIERS (T1 = bestes)`n" RTrim(tierTxt, "`n")
}

OnMinChange(*) {
    global Filling
    if Filling || SelGid = ""
        return
    cat := CurCat()
    if !IsObject(cat)
        return
    w := GetWishes(cat.Id)
    v := Trim(Ctl.Min.Value)
    nv := v = "" ? "" : v + 0
    if !w.Has(SelGid) && nv = ""
        return                                  ; nur angeklickt, nichts eingetragen
    if w.Has(SelGid) && w[SelGid] = nv && (nv != "" || w[SelGid] = "")
        return                                  ; keine Änderung
    w[SelGid] := nv
    ; Zeile in der Liste anhaken und Wert zeigen
    for i, gid in ListRows {
        if gid = SelGid {
            Filling := true
            Ctl.LV.Modify(i, "Check Col4", w[SelGid] = "" ? "egal" : ">= " w[SelGid])
            Filling := false
        }
    }
    WishesChanged(cat)
}

ChangeNeed(d, *) {
    cat := CurCat()
    if !IsObject(cat)
        return
    n := Min(6, Max(1, GetNeed(cat.Id) + d))
    NeedMap[cat.Id] := n
    UpdateSide()
    SaveWishes()
}

ClearWishes(*) {
    cat := CurCat()
    if !IsObject(cat) || GetWishes(cat.Id).Count = 0
        return
    if MsgBox("Alle Häkchen bei '" cat.Sub "' entfernen?", APP, "YesNo Icon? Owner" MainGui.Hwnd) != "Yes"
        return
    Wishes[cat.Id] := Map()
    WishesChanged(cat)
    FillList()
}

WishesChanged(cat) {
    if CatToTv.Has(cat.Id)
        Ctl.TV.Modify(CatToTv[cat.Id], , TreeLabel(cat))
    UpdateSide()
    SetTimer(SaveWishes, -400)
}

UpdateSide() {
    cat := CurCat()
    if !IsObject(cat)
        return
    Ctl.WishCount.Text := GetWishes(cat.Id).Count
    Ctl.Need.Text := GetNeed(cat.Id)
    if SelGid = "" {
        Ctl.SelName.Text := "Klick links auf einen Mod."
        Ctl.Tiers.Text := ""
        Ctl.Min.Value := ""
    }
}

GetWishes(catId) {
    if !Wishes.Has(catId)
        Wishes[catId] := Map()
    return Wishes[catId]
}

GetNeed(catId) => NeedMap.Has(catId) ? NeedMap[catId] : 1

; ============================================================================
;  Speichern / Laden
; ============================================================================
OnMainClose(*) {
    global TrayTipShown
    if !TrayTipShown {
        TrayTip(T("trayTip"), APP)
        TrayTipShown := true
    }
}

SaveAll() {
    try {
        IniWrite(Cfg.Mode, INI, "Einstellungen", "Modus")
        IniWrite(Cfg.PauseMs, INI, "Einstellungen", "PauseMs")
        IniWrite(Cfg.ShiftOnly, INI, "Einstellungen", "NurMitShift")
        IniWrite(Cfg.ItemOverlay, INI, "Einstellungen", "ItemAnzeige")
        IniWrite(Cfg.AutoDetect, INI, "Einstellungen", "AutoErkennen")
        IniWrite(Cfg.Sound, INI, "Einstellungen", "Ton")
        IniWrite(Cfg.Key, INI, "Einstellungen", "Taste")
        IniWrite(Cfg.ActiveCat, INI, "Einstellungen", "AktiveItemArt")
        IniWrite(Cfg.IgnoreFractured, INI, "Einstellungen", "FracturedIgnorieren")
        IniWrite(Cfg.UnsureRelease, INI, "Einstellungen", "UnsicherFreigeben")
        IniWrite(Cfg.StreamVisible, INI, "Einstellungen", "StreamSichtbar")
        IniWrite(Cfg.Volume, INI, "Einstellungen", "Lautstaerke")
        IniWrite(Cfg.SoundName, INI, "Einstellungen", "TrefferSound")
        IniWrite(Cfg.SoundCustom, INI, "Einstellungen", "EigenerSound")
        IniWrite(Cfg.HitBarSecs, INI, "Einstellungen", "TrefferLeisteSek")
        IniWrite(Cfg.HitAnim, INI, "Einstellungen", "TrefferAnimation")
        IniWrite(Cfg.Diag, INI, "Einstellungen", "Diagnose")
        IniWrite(Cfg.Theme, INI, "Einstellungen", "Design")
        IniWrite(Cfg.Lang, INI, "Einstellungen", "Sprache")
        if IsObject(Ctl) && Ctl.HasOwnProp("Wish") {
            f := FileOpen(WISH, "w", "UTF-8")
            f.Write(StrReplace(Ctl.Wish.Value, "`r", ""))
            f.Close()
            LoadRules()
        }
    } catch as e {
        MsgBox("Konnte nicht speichern:`n" e.Message, APP, "Icon!")
        return
    }
    RefreshTarget()
    FlashSaved()
}

SaveWishes() {
    try {
        for catId, w in Wishes {
            s := ""
            for gid, mn in w
                s .= (s = "" ? "" : ",") gid ":" mn
            IniWrite(s, INI, "Wuensche", catId)
        }
        for catId, n in NeedMap
            IniWrite(n, INI, "TrefferAb", catId)
    } catch as e {
        MsgBox("Konnte Wünsche nicht speichern:`n" e.Message, APP, "Icon!")
        return
    }
    RefreshTarget()
    FlashSaved()
}

FlashSaved() {
    if UI_MODE = "web" {
        WebPost(Map("type", "saved"))
        return
    }
    if !IsObject(Ctl) || !Ctl.HasOwnProp("Saved")
        return
    Ctl.Saved.Text := "✔ gespeichert"
    SetTimer(() => Ctl.Saved.Text := "", -1500)
}

LoadWishes() {
    try sec := IniRead(INI, "Wuensche")
    catch
        sec := ""
    for line in StrSplit(sec, "`n", "`r") {
        p := InStr(line, "=")
        if !p
            continue
        catId := SubStr(line, 1, p - 1)
        w := Map()
        for item in StrSplit(SubStr(line, p + 1), ",") {
            kv := StrSplit(item, ":")
            if kv.Length >= 1 && DB.Groups.Has(kv[1])
                w[kv[1]] := (kv.Length < 2 || kv[2] = "") ? "" : IsNumber(kv[2]) ? kv[2] + 0 : RegExMatch(kv[2], "^T\d+$") ? kv[2] : ""
        }
        Wishes[catId] := w
    }
    try sec := IniRead(INI, "TrefferAb")
    catch
        sec := ""
    for line in StrSplit(sec, "`n", "`r") {
        p := InStr(line, "=")
        if p && IsInteger(SubStr(line, p + 1))
            NeedMap[SubStr(line, 1, p - 1)] := Integer(SubStr(line, p + 1))
    }
}

LoadConfig() {
    Cfg.Mode        := Integer(IniRead(INI, "Einstellungen", "Modus", "1"))
    Cfg.PauseMs     := Integer(IniRead(INI, "Einstellungen", "PauseMs", "800"))
    Cfg.ShiftOnly   := Integer(IniRead(INI, "Einstellungen", "NurMitShift", "1"))
    Cfg.ItemOverlay := Integer(IniRead(INI, "Einstellungen", "ItemAnzeige", "1"))
    Cfg.AutoDetect  := Integer(IniRead(INI, "Einstellungen", "AutoErkennen", "1"))
    Cfg.Sound       := Integer(IniRead(INI, "Einstellungen", "Ton", "1"))
    Cfg.Key         := IniRead(INI, "Einstellungen", "Taste", "F6")
    Cfg.ActiveCat   := IniRead(INI, "Einstellungen", "AktiveItemArt", "")
    Cfg.IgnoreFractured := Integer(IniRead(INI, "Einstellungen", "FracturedIgnorieren", "1"))
    Cfg.UnsureRelease := Integer(IniRead(INI, "Einstellungen", "UnsicherFreigeben", "0"))
    Cfg.StreamVisible := Integer(IniRead(INI, "Einstellungen", "StreamSichtbar", "1"))
    Cfg.TargetPanel := 0                        ; Ziel-Fenster gibt es nicht mehr
    Cfg.PosBanner := IniRead(INI, "Positionen", "Meldung", "")
    Cfg.PosItem := IniRead(INI, "Positionen", "ItemAnzeige", "")
    Cfg.PosHit := IniRead(INI, "Positionen", "TrefferLeiste", "")
    Cfg.Volume := Integer(IniRead(INI, "Einstellungen", "Lautstaerke", "80"))
    Cfg.SoundName := IniRead(INI, "Einstellungen", "TrefferSound", "seal")
    if Cfg.SoundName = "slot"                   ; v8: der Spielautomat ist dem Siegel gewichen
        Cfg.SoundName := "seal"
    if !HasVal(SOUNDS, Cfg.SoundName)
        Cfg.SoundName := "seal"
    Cfg.SoundCustom := IniRead(INI, "Einstellungen", "EigenerSound", "")
    Cfg.HitAnim := IniRead(INI, "Einstellungen", "TrefferAnimation", "slot") = "instant" ? "instant" : "slot"
    hs := IniRead(INI, "Einstellungen", "TrefferLeisteSek", "0")
    Cfg.HitBarSecs := HasVal(HITBAR_SECS, IsInteger(hs) ? Integer(hs) : -1) ? Integer(hs) : 0
    Cfg.Diag := Integer(IniRead(INI, "Einstellungen", "Diagnose", "1"))
    ob := IniRead(INI, "Einstellungen", "Texterkennung", "1215")
    Cfg.OcrBest := HasVal(OCR_SETS, IsInteger(ob) ? Integer(ob) : 0) ? Integer(ob) : 1215
    Cfg.Theme       := "obsidian"                    ; v7: nur noch ein Stil
    Cfg.Lang        := IniRead(INI, "Einstellungen", "Sprache", SubStr(A_Language, -2) = "07" ? "de" : "en")
    if !THEMES.Has(Cfg.Theme)
        Cfg.Theme := "obsidian"
    if Cfg.Lang != "en"
        Cfg.Lang := "de"
    if Cfg.Mode != 2 && Cfg.Mode != 3
        Cfg.Mode := 1
    ok := false
    for v in PAUSES
        if v = Cfg.PauseMs
            ok := true
    if !ok
        Cfg.PauseMs := 800
    ok := false
    for k in KEYS
        if k = Cfg.Key
            ok := true
    if !ok
        Cfg.Key := "F6"
}

LoadDB() {
    if !FileExist(MODS_FILE) {
        MsgBox(T("modsMissing"), APP, "Icon!")
        return
    }
    lens := ""
    Loop Read MODS_FILE {
        f := StrSplit(A_LoopReadLine, "`t")
        if f.Length < 2
            continue
        switch f[1] {
            case "V":
                DB.Ver := f[2]
            case "G":
                if f.Length < 9
                    continue
                pats := []
                for p in StrSplit(f[8], "||")
                    pats.Push(StrSplit(p, "¦"))
                ranges := []
                for r in StrSplit(f[9], "|") {
                    lh := StrSplit(r, ":")
                    ranges.Push(lh.Length = 2 ? {Lo: lh[1] + 0, Hi: lh[2] + 0} : "")
                }
                DB.Groups[f[2]] := {Id: f[2], Kind: f[3], Text: f[4], N: f[5], TierTxt: f[7], Pats: pats, Ranges: ranges}
            case "C":
                c := {Id: f[2], Main: f[3], Sub: f[4], Gids: []}
                for gid in StrSplit(f[5], ",")
                    if DB.Groups.Has(gid)
                        c.Gids.Push(gid)
                DB.Cats.Push(c)
                DB.CatById[c.Id] := c
            case "B":
                DB.Bases.Push({Cat: f[2], Name: f[3]})
                lens .= Format("{:04}", StrLen(f[3])) "`t" DB.Bases.Length "`n"
        }
    }
    ; längste Basisnamen zuerst prüfen (z.B. "Time-Lost Ruby" vor "Ruby")
    sorted := []
    for line in StrSplit(Sort(RTrim(lens, "`n"), "R"), "`n") {
        p := StrSplit(line, "`t")
        if p.Length = 2
            sorted.Push(DB.Bases[Integer(p[2])])
    }
    DB.Bases := sorted
}

KeyLabel() => Cfg.Key

RegisterKey(newKey) {
    global CurKey
    HotIf(PoEHotIf)
    if CurKey != "" && CurKey != newKey
        try Hotkey(CurKey, "Off")
    Hotkey(newKey, ToggleGuard, "On")
    HotIf()
    CurKey := newKey
}

LoadRules() {
    global Rules
    Rules := []
    try text := FileRead(WISH, "UTF-8")
    catch
        return
    for line in StrSplit(text, "`n", "`r") {
        line := Trim(line)
        if line = "" || SubStr(line, 1, 1) = "#" || SubStr(line, 1, 1) = ";"
            continue
        if RegExMatch(line, "^(.*?)\s*(>=|<=)\s*(-?\d+(?:[.,]\d+)?)\s*$", &m) && Trim(m[1]) != ""
            Rules.Push({Text: Trim(m[1]), Op: m[2], Val: StrReplace(m[3], ",", ".") + 0})
        else
            Rules.Push({Text: line, Op: "", Val: 0})
    }
}

EnsureWishlist() {
    if FileExist(WISH)
        return
    tmpl := "
    (
# ===== EIGENE WÜNSCHE ALS TEXT (optional) =====
# Normalerweise hakst du deine Wünsche im Reiter "Mods wählen" an.
# Hier kannst du zusätzlich Text-Wünsche eintragen, die für ALLE Items gelten.
# Praktisch, wenn du den Spiel-Client auf Deutsch spielst.
# Eine Zeile = ein Wunsch.  Mit  >= Zahl  meinst du: mindestens so viel.
# Zeilen mit # am Anfang sind ausgeschaltet.
#
# Bewegungsgeschwindigkeit >= 30
# maximalem Leben >= 100
# Feuerwiderstand >= 35
    )"
    f := FileOpen(WISH, "w", "UTF-8")
    f.Write(tmpl)
    f.Close()
}

; ============================================================================
;  Optik-Helfer (dunkles Windows-Design)
; ============================================================================
DarkEdit(e, fg := "") {
    ; dunkler Hintergrund + helle Schrift - falls nicht möglich, bleibt das Feld hell und lesbar
    try {
        e.Opt("+Background" Clr.Field)
        e.SetFont("c" (fg = "" ? Clr.Text : fg))
    } catch {
        e.SetFont("c000000")
    }
    return e
}

Dark(hwnd, theme := "DarkMode_Explorer") {
    try DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", theme, "Ptr", 0)
}

DarkTitle(hwnd) {
    v := Buffer(4, 0), NumPut("Int", 1, v)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 20, "Ptr", v, "UInt", 4)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 19, "Ptr", v, "UInt", 4)
    col := Buffer(4, 0)
    rgb := Integer("0x" Clr.Panel)
    NumPut("UInt", ((rgb & 0xFF) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 0xFF), col)   ; Windows 11 Titelleisten-Farbe
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 35, "Ptr", col, "UInt", 4)
}

; ============================================================================
;  Einrichten / Update / Entfernen / Tray
; ============================================================================
MaybeInstall() {
    if A_ScriptDir = INSTALL_DIR || FileExist(A_ScriptDir "\portable.txt")
        return
    isUpdate := FileExist(INSTALL_DIR "\" APP_FILE ".ahk") || FileExist(OLD_DIR "\PoE2-CraftSchutz.ahk")
    fromSetup := HasVal(A_Args, "/setup")             ; von ChaosWard-Setup.exe entpackt -> ohne Rückfrage einrichten
    if !fromSetup {
        msg := StrReplace(T(isUpdate ? "instUpd" : "instNew"), "{v}", APP_VER)
        r := MsgBox(msg, APP, "YesNoCancel Iconi")
        if r = "Cancel"
            ExitApp
        if r = "No"
            return
    }
    try {
        ; laufende alte Version beenden
        DetectHiddenWindows true
        try WinClose(INSTALL_DIR "\" APP_FILE ".ahk ahk_class AutoHotkey")
        try WinClose(OLD_DIR "\PoE2-CraftSchutz.ahk ahk_class AutoHotkey")
        DetectHiddenWindows false
        Sleep 600
        DirCreate(INSTALL_DIR)
        ; Wünsche und Einstellungen der alten Version (Craft-Schutz) mitnehmen
        for f in ["Wunschliste.txt", "Einstellungen.ini"]
            if FileExist(OLD_DIR "\" f) && !FileExist(INSTALL_DIR "\" f)
                FileCopy(OLD_DIR "\" f, INSTALL_DIR "\" f)
        FileCopy(A_AhkPath, INSTALL_DIR "\" APP_FILE ".exe", 1)
        FileCopy(A_ScriptFullPath, INSTALL_DIR "\" APP_FILE ".ahk", 1)
        FileCopy(A_ScriptDir "\Mods.tsv", INSTALL_DIR "\Mods.tsv", 1)
        for d in ["ui", "lib"]
            if DirExist(A_ScriptDir "\" d)
                DirCopy(A_ScriptDir "\" d, INSTALL_DIR "\" d, 1)
        for f in ["Wunschliste.txt", "Einstellungen.ini"]      ; eigene Sachen bei Update behalten
            if FileExist(A_ScriptDir "\" f) && !FileExist(INSTALL_DIR "\" f)
                FileCopy(A_ScriptDir "\" f, INSTALL_DIR "\" f)
        for f in ["LIZENZ-AutoHotkey.txt", "LIES MICH.txt", "LIZENZ.txt"]
            if FileExist(A_ScriptDir "\" f)
                FileCopy(A_ScriptDir "\" f, INSTALL_DIR "\" f, 1)
        exe := INSTALL_DIR "\" APP_FILE ".exe"
        ico := INSTALL_DIR "\ui\icon.ico"
        FileCreateShortcut(exe, A_Desktop "\" LNK_NAME, INSTALL_DIR, , "Chaos Ward - Craft-Schutz für Path of Exile 2", ico)
        FileCreateShortcut(exe, A_Programs "\" LNK_NAME, INSTALL_DIR, , "Chaos Ward - Craft-Schutz für Path of Exile 2", ico)
        ; alte Version aufräumen
        try FileDelete(A_Desktop "\PoE2 Craft-Schutz.lnk")
        try FileDelete(A_Programs "\PoE2 Craft-Schutz.lnk")
        RegisterUninstall()
        if DirExist(OLD_DIR)
            Run(A_ComSpec ' /c timeout /t 5 /nobreak >nul & rmdir /s /q "' OLD_DIR '"', , "Hide")
    } catch as e {
        MsgBox(T("instFail") "`n" e.Message, APP, "Icon!")
        return
    }
    MsgBox(T(fromSetup ? (isUpdate ? "instUpdDoneS" : "instDoneS") : (isUpdate ? "instUpdDone" : "instDone")), APP, "Iconi")
    Run('"' INSTALL_DIR "\" APP_FILE '.exe"', INSTALL_DIR)
    if fromSetup && InStr(A_ScriptDir, "\ChaosWardSetup-")   ; entpackten Temp-Ordner wegräumen
        Run(A_ComSpec ' /c timeout /t 4 /nobreak >nul & rmdir /s /q "' A_ScriptDir '"', , "Hide")
    ExitApp
}

; Eintrag in Windows "Einstellungen -> Apps" (nur für diesen Benutzer, keine Admin-Rechte nötig)
RegisterUninstall() {
    k := "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\ChaosWard"
    exe := INSTALL_DIR "\" APP_FILE ".exe"
    kb := 0
    loop files INSTALL_DIR "\*", "R"
        kb += A_LoopFileSize // 1024
    try {
        RegWrite("Chaos Ward", "REG_SZ", k, "DisplayName")
        RegWrite(APP_VER, "REG_SZ", k, "DisplayVersion")
        RegWrite("moemor", "REG_SZ", k, "Publisher")
        RegWrite(INSTALL_DIR "\ui\icon.ico", "REG_SZ", k, "DisplayIcon")
        RegWrite(INSTALL_DIR, "REG_SZ", k, "InstallLocation")
        RegWrite('"' exe '" "' INSTALL_DIR "\" APP_FILE '.ahk" /uninstall', "REG_SZ", k, "UninstallString")   ; Skript nennen, sonst gilt /uninstall als Skriptname
        RegWrite(1, "REG_DWORD", k, "NoModify")
        RegWrite(1, "REG_DWORD", k, "NoRepair")
        RegWrite(kb, "REG_DWORD", k, "EstimatedSize")
    }
}

Uninstall(*) {
    if MsgBox(T("unQ"), APP, "YesNo Icon?" (IsObject(MainGui) ? " Owner" MainGui.Hwnd : "")) != "Yes"
        return
    try FileDelete(A_Desktop "\" LNK_NAME)
    try FileDelete(A_Programs "\" LNK_NAME)
    try RegDeleteKey("HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\ChaosWard")
    MsgBox(T("unBye"), APP, "Iconi")
    Run(A_ComSpec ' /c timeout /t 4 /nobreak >nul & rmdir /s /q "' INSTALL_DIR '"', , "Hide")
    ExitApp
}

SetupTray() {
    A_IconTip := APP
    m := A_TrayMenu
    m.Delete()
    m.Add(T("trayOpen"), (*) => MainGui.Show())
    m.Add(T("trayToggle"), ToggleGuard)
    m.Add()
    m.Add(T("trayExit"), (*) => ExitApp())
    m.Default := T("trayOpen")
    m.ClickCount := 1
}

; ============================================================================
;  Neue Oberfläche (WebView2 - in Windows 10/11 eingebaut)
;  Klappt das nicht, startet automatisch die einfache Oberfläche.
; ============================================================================
BuildUI() {
    global UI_MODE
    if FileExist(A_ScriptDir "\ui\index.html") && BuildWebUI()
        return
    UI_MODE := "native"
    BuildMain()
    MainGui.Show("w1110 h740")
}

BuildWebUI() {
    global MainGui, WV, WVC, UI_MODE
    g := 0
    try {
        g := Gui("+Resize +MinSize960x620", APP)
        g.BackColor := THEMES[Cfg.Theme]
        g.OnEvent("Close", OnMainClose)
        g.OnEvent("Size", OnWebSize)
        g.Show("w1180 h780")
        ApplyTitleTheme(g.Hwnd)
        DirCreate(DATA_DIR)
        WVC := WebView2.create(g.Hwnd, , 0, DATA_DIR)
        try WVC.DefaultBackgroundColor := ArgbOf(THEMES[Cfg.Theme])
        WV := WVC.CoreWebView2
        wvSet := WV.Settings
        try wvSet.AreDevToolsEnabled := false
        try wvSet.AreDefaultContextMenusEnabled := false
        try wvSet.IsStatusBarEnabled := false
        try wvSet.IsZoomControlEnabled := false
        WV.SetVirtualHostNameToFolderMapping("craftschutz.localhost", A_ScriptDir, 1)
        WV.add_WebMessageReceived(OnWebMessage)
        WV.Navigate("https://craftschutz.localhost/ui/index.html")
        MainGui := g
        UI_MODE := "web"
        return true
    } catch {
        WV := 0, WVC := 0
        if IsObject(g)
            try g.Destroy()
        return false
    }
}

OnWebSize(g, minMax, w, h) {
    if minMax != -1 && IsObject(WVC)
        try WVC.Fill()
}

OnWebMessage(sender, args) {
    try msg := args.TryGetWebMessageAsString()
    catch
        return
    SetTimer(HandleWeb.Bind(msg), -1)      ; außerhalb des WebView-Ereignisses ausführen
}

HandleWeb(msg) {
    global OcrCalib, CurPage, LastItemText
    p := StrSplit(msg, Chr(31))
    switch p[1] {
        case "ready":
            SendState()
            PushStats()
        case "toggle":
            ToggleGuard()
        case "set":
            if p.Length >= 3
                SetOpt(p[2], p[3])
        case "wish":
            if p.Length >= 4 && DB.Groups.Has(p[3]) {
                v := Trim(p[4])
                GetWishes(p[2])[p[3]] := IsNumber(v) ? v + 0 : RegExMatch(v, "^T\d+$") ? v : ""
                SaveWishes()
            }
        case "unwish":
            if p.Length >= 3 {
                w := GetWishes(p[2])
                if w.Has(p[3])
                    w.Delete(p[3])
                SaveWishes()
            }
        case "need":
            if p.Length >= 3 && IsInteger(p[3]) {
                NeedMap[p[2]] := Min(6, Max(1, Integer(p[3])))
                SaveWishes()
            }
        case "clear":
            if p.Length >= 2 {
                Wishes[p[2]] := Map()
                SaveWishes()
            }
        case "rules":
            try {
                f := FileOpen(WISH, "w", "UTF-8")
                f.Write(p.Length >= 2 ? p[2] : "")
                f.Close()
            }
            LoadRules()
            RefreshTarget()
            FlashSaved()
        case "placeStart":
            PlaceStart()
        case "placeReset":
            PlaceReset(false)
        case "kofi":                             ; Unterstützen-Knopf: Ko-fi im normalen Browser öffnen
            try Run("https://ko-fi.com/chaosward")
        case "diagPack":
            zip := ""
            try zip := DiagPack()
            if zip != "" {
                Run('explorer.exe /select,"' zip '"')
                WebPost(Map("type", "toast", "text", T("diagPackOk"), "long", 1))
            } else {
                WebPost(Map("type", "toast", "text", T("diagPackFail"), "long", 1))
            }
        case "openDiag":
            DirCreate(DIAG_DIR)
            Run('explorer.exe "' DIAG_DIR '"')
        case "resetLearn":
            Aliases.Clear(), NumFixes.Clear()
            SaveLearned()
            SendState()
        case "mbRule":
            if p.Length >= 3 && IsInteger(p[3]) && HasVal(LEGACIES, p[2]) {
                n := Max(0, Min(4, Integer(p[3])))
                if n = 0 {
                    if Mb.Rules.Has(p[2])
                        Mb.Rules.Delete(p[2])
                } else {
                    Mb.Rules[p[2]] := n
                    if Mb.Ban.Has(p[2])
                        Mb.Ban.Delete(p[2])
                }
                SaveMb()
            }
        case "mbAny":
            if p.Length >= 2 && IsInteger(p[2]) {
                Mb.Any := Max(0, Min(4, Integer(p[2])))
                SaveMb()
            }
        case "mbEff":
            if p.Length >= 2 {
                Mb.Eff := IsNumber(Trim(p[2])) ? Trim(p[2]) + 0 : ""
                SaveMb()
            }
        case "mbBan":
            if p.Length >= 3 && HasVal(LEGACIES, p[2]) {
                if p[3] = "1" {
                    Mb.Ban[p[2]] := true
                    if Mb.Rules.Has(p[2])
                        Mb.Rules.Delete(p[2])
                } else if Mb.Ban.Has(p[2]) {
                    Mb.Ban.Delete(p[2])
                }
                SaveMb()
            }
        case "mbDup":
            if p.Length >= 2 {
                Mb.Dup := p[2] = "1" ? 1 : 0
                SaveMb()
            }
        case "tab":
            CurPage := p.Length >= 2 ? p[2] : ""
        case "dvRule":
            if p.Length >= 5 && IsInteger(p[3]) {
                key := p[2], idx := Integer(p[3])
                if p[5] = "" || !IsNumber(p[5]) {
                    if Dv.Rules.Has(key) && Dv.Rules[key].Has(idx)
                        Dv.Rules[key].Delete(idx)
                    if Dv.Rules.Has(key) && Dv.Rules[key].Count = 0
                        Dv.Rules.Delete(key)
                } else {
                    if !Dv.Rules.Has(key)
                        Dv.Rules[key] := Map()
                    Dv.Rules[key][idx] := {Op: p[4] = "<=" ? "<=" : ">=", Val: p[5] + 0}
                }
                SaveDv()
            }
        case "dvTake":                         ; "Letztes kopiertes Item übernehmen"
            item := LastItemText != "" ? ParseItem(LastItemText) : 0
            if IsObject(item)
                DvFlowSafe(item, true)
            else
                WebPost(Map("type", "toast", "text", T("dvNoItem"), "long", 1))
        case "dvPaste":                        ; Strg+V im Divine-Reiter
            txt := SubStr(msg, StrLen("dvPaste") + 2)
            item := CheckGameLang(txt) ? ParseItem(txt) : 0
            if IsObject(item) {
                LastItemText := txt
                DvFlowSafe(item, true)
            } else {
                WebPost(Map("type", "toast", "text", T("dvNotItem"), "long", 1))
            }
        case "dvAny":
            Dv.Any := (p.Length >= 2 && p[2] = "1") ? 1 : 0
            SaveDv()
        case "dvClear":
            Dv.Rules := Map()
            SaveDv()
            SendDv()
        case "dvForget":
            Dv.Item := "", Dv.Lines := [], Dv.Rules := Map()
            SaveDv()
            SendDv()
        case "mbClear":
            Mb.Rules := Map(), Mb.Any := 0, Mb.Eff := "", Mb.Ban := Map(), Mb.Dup := 0
            SaveMb()
        case "soundTest":
            PlayHitSound(true)
        case "soundPick":
            f := ""
            try f := FileSelect(1, A_MyDocuments, T("sndPick"), "Audio (*.wav; *.mp3)")
            if f != "" {
                Cfg.SoundCustom := f, Cfg.SoundName := "custom"
                SaveAll()
                PlayHitSound(true)
            }
            SendState()
        case "sysCheck":
            WebPost(Map("type", "sys", "items", SysCheck()))
        case "restartAdmin":
            RestartAsAdmin()
        case "ocrReset":
            Cfg.OcrBest := OCR_SETS[1]
            try IniWrite(Cfg.OcrBest, INI, "Einstellungen", "Texterkennung")
            OcrCalib := ""
            SendState()
        case "testHitDv":
            if !St.Hit {
                if ShowHitBar(1, Max(Stats.SinceHit, 12), "dv", "", ReelDvTest()) {
                    SetTimer(HideHitBar, -6000)
                } else {
                    ShowBanner("Treffer-Leiste: Fehler (v" APP_VER ")", HitBarErr, Clr.Red)
                    SetTimer(HideBanner, -8000)
                }
            }
            HitSoundSynced("dv", true)
        case "testHit":
            if !St.Hit {
                if ShowHitBar(1, Max(Stats.SinceHit, 37), "", "", ReelDemo()) {
                    SetTimer(HideHitBar, -5500)
                } else {
                    ShowBanner("Treffer-Leiste: Fehler (v" APP_VER ")", HitBarErr, Clr.Red)
                    SetTimer(HideBanner, -8000)
                }
            }
            HitSoundSynced("", true)
        case "resetSession":
            Stats.Session := 0, Stats.SinceHit := 0
            StatsChanged()
        case "resetAll":
            Stats.Session := 0, Stats.SinceHit := 0, Stats.Total := 0, Stats.History := []
            StatsChanged()
        case "uninstall":
            Uninstall()
    }
}

SetOpt(key, val) {
    switch key {
        case "Mode":
            Cfg.Mode := (val = 2 || val = 3) ? Integer(val) : 1
        case "PauseMs":
            for v in PAUSES
                if IsInteger(val) && v = Integer(val)
                    Cfg.PauseMs := v
        case "Key":
            for k in KEYS
                if k = val {
                    Cfg.Key := k
                    RegisterKey(k)
                }
            PushStatus()
        case "Theme":
            if THEMES.Has(val) {
                Cfg.Theme := val
                MainGui.BackColor := THEMES[val]
                ApplyTitleTheme(MainGui.Hwnd)
                try WVC.DefaultBackgroundColor := ArgbOf(THEMES[val])
            }
        case "Lang":
            if val = "de" || val = "en" {
                Cfg.Lang := val
                SetupTray()
            }
        case "Volume":
            if IsInteger(val)
                Cfg.Volume := Max(0, Min(100, Integer(val)))
        case "SoundName":
            if HasVal(SOUNDS, val)
                Cfg.SoundName := val
        case "HitAnim":
            Cfg.HitAnim := val = "instant" ? "instant" : "slot"
        case "HitBarSecs":
            if IsInteger(val) && HasVal(HITBAR_SECS, Integer(val))
                Cfg.HitBarSecs := Integer(val)
        case "ActiveCat":
            if DB.CatById.Has(val)
                Cfg.ActiveCat := val
        case "ShiftOnly", "ItemOverlay", "AutoDetect", "Sound", "IgnoreFractured", "UnsureRelease", "StreamVisible", "Diag":
            Cfg.%key% := (val = "1") ? 1 : 0
        default:
            return
    }
    SaveAll()
    if key = "ShiftOnly" && St.On && !St.Locked
        ShowOnBanner()
}

SendState() {
    rulesTxt := ""
    try rulesTxt := FileRead(WISH, "UTF-8")
    WebPost(Map("type", "state", "lang", Cfg.Lang, "theme", Cfg.Theme, "mode", Cfg.Mode, "pauseMs", Cfg.PauseMs
        , "shiftOnly", Cfg.ShiftOnly, "itemOverlay", Cfg.ItemOverlay, "autoDetect", Cfg.AutoDetect, "sound", Cfg.Sound
        , "ignoreFractured", Cfg.IgnoreFractured, "unsureRelease", Cfg.UnsureRelease, "streamVisible", Cfg.StreamVisible, "targetPanel", Cfg.TargetPanel, "volume", Cfg.Volume, "diag", Cfg.Diag, "learned", Aliases.Count + NumFixes.Count, "key", Cfg.Key, "keys", KEYS, "activeCat", Cfg.ActiveCat
        , "on", St.On ? 1 : 0, "hit", St.Hit ? 1 : 0, "wishes", Wishes, "need", NeedMap, "rules", rulesTxt
        , "ver", APP_VER, "installed", (A_ScriptDir = INSTALL_DIR) ? 1 : 0
        , "mb", Map("rules", Mb.Rules, "any", Mb.Any, "eff", Mb.Eff, "ban", MbBanList(), "dup", Mb.Dup), "legacies", LEGACIES
        , "soundName", Cfg.SoundName, "soundCustom", Cfg.SoundCustom = "" ? "" : RegExReplace(Cfg.SoundCustom, ".*\\"), "hitBarSecs", Cfg.HitBarSecs, "hitAnim", Cfg.HitAnim
        , "ocr", OcrInfo(), "dv", DvState()))
}

OcrHasEnglish() {
    langs := ""
    try langs := OCR.GetAvailableLanguages()
    return RegExMatch(langs, "im)^en-") > 0
}

OcrInfo() => Map("best", Cfg.OcrBest, "last", OcrCalib, "lang", OcrLanguage(), "en", OcrHasEnglish() ? 1 : 0)
SendOcr() => WebPost(Map("type", "ocr", "ocr", OcrInfo()))

PushStatus() => WebPost(Map("type", "status", "on", St.On ? 1 : 0, "hit", St.Hit ? 1 : 0))

WebPost(obj) {
    if UI_MODE != "web" || !IsObject(WV)
        return
    try WV.PostWebMessageAsJson(Jsonify(obj))
}

Jsonify(v) {
    if v is Map {
        out := ""
        for k, x in v
            out .= (out = "" ? "" : ",") JStr(String(k)) ":" Jsonify(x)
        return "{" out "}"
    }
    if v is Array {
        out := ""
        for x in v
            out .= (out = "" ? "" : ",") Jsonify(x)
        return "[" out "]"
    }
    if IsObject(v) {
        out := ""
        for k, x in v.OwnProps()
            out .= (out = "" ? "" : ",") JStr(String(k)) ":" Jsonify(x)
        return "{" out "}"
    }
    if v is Number
        return String(v)
    return JStr(String(v))
}

JStr(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`r", "")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`t", "\t")
    return '"' s '"'
}

ArgbOf(hex) {
    rgb := Integer("0x" hex)
    return ((((rgb & 0xFF) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 0xFF)) << 8) | 0xFF
}

ApplyTitleTheme(hwnd) {
    isDark := Cfg.Theme != "frost"
    v := Buffer(4, 0), NumPut("Int", isDark ? 1 : 0, v)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 20, "Ptr", v, "UInt", 4)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 19, "Ptr", v, "UInt", 4)
    rgb := Integer("0x" THEMES[Cfg.Theme])
    col := Buffer(4, 0)
    NumPut("UInt", ((rgb & 0xFF) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 0xFF), col)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 35, "Ptr", col, "UInt", 4)
}

; ============================================================================
;  Sprache (Deutsch / English)
; ============================================================================
T(key) {
    static de := Map(
        "bPause", "Kurze Pause ...",
        "bCopy", "Jetzt Strg+C drücken",
        "bCopySub", "Shift loslassen, Maus aufs Item - dann prüfe ich es",
        "bOff", "Chaos Ward AUS",
        "bOn", "Chaos Ward AN",
        "bShift", "Shift halten + klicken",
        "bClick", "klicken",
        "bOffKey", "{k} = aus",
        "bHit", "TREFFER!   STOPP!",
        "bHitSub", "{n} Wunsch-Mod(s) gefunden - Klicken ist gesperrt.`nDrück {k}, wenn du fertig bist.",
        "bNoCopy", "Strg+C hat nichts kopiert",
        "bNoCopySub", "Lass Shift los, halte die Maus aufs Item und drück nochmal Strg+C",
        "bStart", "Einmal Strg+C zum Start",
        "bStartSub", "Maus aufs Item, Shift loslassen, Strg+C - dann lese ich ab jetzt mit",
        "bTrack", "Mitlesen aktiv - jetzt spammen",
        "bTrackSub", "Ich lese den Tooltip nach jedem Klick und stoppe beim Wunsch-Mod",
        "bNoTip", "Tooltip nicht gefunden",
        "bUnsure", "Nicht sicher lesbar",
        "bNoChange", "Keine Änderung erkannt",
        "bCheckSub", "Zur Sicherheit gesperrt. Strg+C prüft das Item - oder {k} zum Beenden",
        "bOcrFail", "Texterkennung nicht verfügbar",
        "bReleased", "Nicht sicher gelesen - freigegeben",
        "bLearned", "Gemerkt: {n} neue Schreibweise(n) gelernt",
        "hTitle", "TREFFER", "hTitleDv", "TREFFER", "hSubDv", "Alle {n} Schwellen erreicht", "hSubDvOne", "Schwelle erreicht", "hDivines", "DIVINES",
        "hSpin", "Walze dreht …", "hSpinDv", "Werte rollen …",
        "mbAny", "Beliebiges Legacy mindestens {n}×",
        "mbEff", "Effekt pro Duplikat mindestens {n}%",
        "mbAll", "Stopp, wenn ALLES davon erfüllt ist",
        "bHitLocked", "Treffer – Klick bleibt gesperrt", "bHitLockedSub", "{k} drücken, wenn du fertig bist",
        "sndPick", "Eigenen Treffer-Sound wählen",
        "bNoEnSub", "Englisches Sprachpaket fehlt: Windows-Einstellungen → Zeit und Sprache → Sprache hinzufügen → Englisch",
        "bLang", "Spiel ist nicht auf Englisch",
        "bLangSub", "Chaos Ward kennt nur die englischen Mod-Texte. Im Spiel: Optionen → Sprache → English",
        "mAdmin", "Path of Exile 2 läuft als Administrator.`n`nDann blockiert Windows die Klick-Sperre von Chaos Ward - deine Klicks würden NICHT gestoppt.`n`nChaos Ward jetzt auch als Administrator neu starten?",
        "mAdminFail", "Neustart als Administrator hat nicht geklappt. Starte Chaos Ward per Rechtsklick → Als Administrator ausführen.",
        "bFullscreen", "Chaos Ward: echtes Vollbild erkannt",
        "bFullscreenSub", "Im echten Vollbild sind die Anzeigen unsichtbar. Im Spiel auf Fenster-Vollbild (Windowed Fullscreen) stellen.",
        "dvAll", "alle Schwellen", "dvOne", "eine Schwelle reicht",
        "dvLoaded", "Divine: Item übernommen", "dvLoadedSub", "{n} Zahlen – jetzt Schwellen einstellen",
        "dvErr", "Fehler beim Einlesen", "dvNoItem", "Noch kein Item kopiert – im Spiel Maus aufs Item und Strg+C",
        "dvNotItem", "Das ist kein Item-Text aus PoE2 (im Spiel Strg+C auf das Item, dann hier Strg+V)",
        "plBanner", "Meldungen", "plHit", "Treffer-Leiste", "plItem", "Item-Anzeige",
        "plDrag", "Mit der Maus an die gewünschte Stelle ziehen",
        "plDone", "Fertig", "plReset", "Standard", "plSaved", "Positionen gespeichert",
        "mbOr", "Stopp bei Wunsch-Legacies ODER irgendeinem Duplikat",
        "mbDup", "Irgendein Legacy doppelt (egal welche Kombi)",
        "mbBan", "Nicht gewollt",
        "hSub", "{n} Wunsch-Mods gefunden", "hLocked", "Klick gesperrt",
        "hHint", "{k} drücken, wenn du fertig bist",
        "hOrbs", "ORBS",
        "pTitle", "DU SUCHST",
        "pNone", "Noch nichts angehakt - wähle Mods in Chaos Ward",
        "pStopOne", "Stopp, sobald 1 Wunsch-Mod drauf ist",
        "pStopMany", "Stopp, wenn {n} Wunsch-Mods gleichzeitig drauf sind",
        "pCount", "Orbs:  {s} seit Treffer   ·   {n} Sitzung   ·   {t} gesamt",
        "tAny", "jedes Tier",
        "tUpTo", "T1–T{n}",
        "bReleasedSub", "Schau selbst kurz drauf (Option: bei Unsicherheit freigeben)",
        "bWeak", "Mitlesen aktiv - Erkennung schwach",
        "bWeakSub", "Nur {a} von {b} Mods erkannt. Tooltip frei sichtbar halten (nicht über Icons)",
        "bTrackQ", "{a} von {b} Mods sicher erkannt - jetzt spammen",
        "oUnknown", "Item-Art unbekannt",
        "oHits", "{n} Wunsch-Mod(s)  ·  Stopp ab {m}",
        "oNoMods", "Keine Mods gefunden (noch nicht identifiziert?)",
        "trayTip", "Ich laufe unten rechts bei der Uhr weiter.`nKlick auf mein Symbol, um mich wieder zu öffnen.",
        "trayOpen", "Fenster öffnen",
        "trayToggle", "Schutz an / aus",
        "trayExit", "Beenden",
        "modsMissing", "Die Datei 'Mods.tsv' fehlt.`nBitte den ganzen Ordner aus der ZIP entpacken.",
        "instNew", "Hallo!`n`nSoll ich Chaos Ward auf deinem PC einrichten?`n`n   •  ein Symbol auf dem Desktop`n   •  ein Eintrag im Startmenü`n`nJa  = einrichten (empfohlen)`nNein  = nur dieses eine Mal so starten",
        "instUpd", "Hallo!`n`nChaos Ward (früher Craft-Schutz) ist schon auf deinem PC.`nSoll ich ihn auf Version {v} aktualisieren?`n`nDeine Wünsche und Einstellungen bleiben erhalten.`n`nJa  = aktualisieren (empfohlen)`nNein  = nur dieses eine Mal so starten",
        "instFail", "Einrichten hat nicht geklappt. Ich starte einfach so.",
        "diagPackOk", "Diagnose-Paket liegt auf dem Desktop – schick mir diese ZIP-Datei",
        "diagPackFail", "Diagnose-Paket konnte nicht erstellt werden",
        "instDoneS", "Fertig eingerichtet!`n`nAuf dem Desktop und im Startmenü ist jetzt 'Chaos Ward'.`nDie Setup-Datei kannst du löschen.",
        "instUpdDoneS", "Update fertig!`n`nDeine Wünsche und Einstellungen sind erhalten.`nDie Setup-Datei kannst du löschen.",
        "instDone", "Fertig eingerichtet!`n`nAuf deinem Desktop ist das Symbol 'Chaos Ward'.`nDen entpackten Ordner kannst du jetzt löschen.",
        "instUpdDone", "Fertig aktualisiert!`n`nAuf deinem Desktop ist das Symbol 'Chaos Ward'.`nDen entpackten Ordner kannst du jetzt löschen.",
        "unQ", "Soll ich Chaos Ward wirklich vom PC entfernen?",
        "unBye", "Erledigt. Tschüss!")
    static en := Map(
        "bPause", "Short pause ...",
        "bCopy", "Now press Ctrl+C",
        "bCopySub", "Let go of Shift, hover the item - then I'll check it",
        "bOff", "Chaos Ward OFF",
        "bOn", "Chaos Ward ON",
        "bShift", "hold Shift + click",
        "bClick", "click",
        "bOffKey", "{k} = off",
        "bHit", "HIT!   STOP!",
        "bHitSub", "{n} wished mod(s) found - clicking is blocked.`nPress {k} when you're done.",
        "bNoCopy", "Ctrl+C didn't copy anything",
        "bNoCopySub", "Let go of Shift, hover the item and press Ctrl+C again",
        "bStart", "Press Ctrl+C once to start",
        "bStartSub", "Hover the item, let go of Shift, Ctrl+C - from then on I read along",
        "bTrack", "Reading along - spam away",
        "bTrackSub", "I read the tooltip after every click and stop on a wished mod",
        "bNoTip", "Tooltip not found",
        "bUnsure", "Couldn't read it reliably",
        "bNoChange", "No change detected",
        "bCheckSub", "Blocked to be safe. Ctrl+C checks the item - or {k} to finish",
        "bOcrFail", "Text recognition not available",
        "bReleased", "Not read reliably - released",
        "bLearned", "Learned {n} new spelling(s)",
        "hTitle", "HIT", "hTitleDv", "HIT", "hSubDv", "All {n} thresholds reached", "hSubDvOne", "Threshold reached", "hDivines", "DIVINES",
        "hSpin", "Reel spinning …", "hSpinDv", "Rolling values …",
        "mbAny", "Any Legacy at least {n}×",
        "mbEff", "Effect per duplicate at least {n}%",
        "mbAll", "Stop when ALL of this is met",
        "bHitLocked", "Hit – clicking stays locked", "bHitLockedSub", "Press {k} when you're done",
        "sndPick", "Choose your own hit sound",
        "bNoEnSub", "English language pack missing: Windows Settings → Time & language → Add a language → English",
        "bLang", "Game is not set to English",
        "bLangSub", "Chaos Ward only knows the English mod texts. In game: Options → Language → English",
        "mAdmin", "Path of Exile 2 is running as administrator.`n`nThen Windows blocks Chaos Ward's click lock - your clicks would NOT be stopped.`n`nRestart Chaos Ward as administrator now?",
        "mAdminFail", "Restarting as administrator didn't work. Start Chaos Ward via right-click → Run as administrator.",
        "bFullscreen", "Chaos Ward: exclusive fullscreen detected",
        "bFullscreenSub", "In exclusive fullscreen the overlays are invisible. Set the game to Windowed Fullscreen.",
        "dvAll", "all thresholds", "dvOne", "one threshold is enough",
        "dvLoaded", "Divine: item loaded", "dvLoadedSub", "{n} numbers – now set thresholds",
        "dvErr", "error while reading", "dvNoItem", "No item copied yet – in game hover the item and press Ctrl+C",
        "dvNotItem", "That's not PoE2 item text (in game Ctrl+C on the item, then Ctrl+V here)",
        "plBanner", "Messages", "plHit", "Hit bar", "plItem", "Item display",
        "plDrag", "Drag to where you want it with the mouse",
        "plDone", "Done", "plReset", "Default", "plSaved", "Positions saved",
        "mbOr", "Stop on wished legacies OR any duplicate",
        "mbDup", "Any legacy duplicated (any combination)",
        "mbBan", "Not wanted",
        "hSub", "{n} wished mods found", "hLocked", "Click locked",
        "hHint", "Press {k} when you're done",
        "hOrbs", "ORBS",
        "pTitle", "YOU'RE LOOKING FOR",
        "pNone", "Nothing picked yet - choose mods in Chaos Ward",
        "pStopOne", "Stop as soon as 1 wished mod lands",
        "pStopMany", "Stop when {n} wished mods are on at once",
        "pCount", "Orbs:  {s} since hit   ·   {n} session   ·   {t} total",
        "tAny", "any tier",
        "tUpTo", "T1–T{n}",
        "bReleasedSub", "Take a quick look yourself (option: release when unsure)",
        "bWeak", "Reading along - recognition weak",
        "bWeakSub", "Only {a} of {b} mods recognized. Keep the tooltip clearly visible (not over icons)",
        "bTrackQ", "{a} of {b} mods recognized - spam away",
        "oUnknown", "Unknown item type",
        "oHits", "{n} wished mod(s)  ·  stop at {m}",
        "oNoMods", "No mods found (not identified yet?)",
        "trayTip", "I keep running next to the clock.`nClick my icon to open me again.",
        "trayOpen", "Open window",
        "trayToggle", "Guard on / off",
        "trayExit", "Exit",
        "modsMissing", "The file 'Mods.tsv' is missing.`nPlease extract the whole folder from the ZIP.",
        "instNew", "Hi!`n`nShall I set up Chaos Ward on your PC?`n`n   •  an icon on your desktop`n   •  a Start menu entry`n`nYes  = set up (recommended)`nNo  = just run it this once",
        "instUpd", "Hi!`n`nChaos Ward (formerly Craft-Schutz) is already on your PC.`nShall I update it to version {v}?`n`nYour wishes and settings are kept.`n`nYes  = update (recommended)`nNo  = just run it this once",
        "instFail", "Setup didn't work. I'll just run from here.",
        "diagPackOk", "Diagnostic package saved on your desktop – send me this ZIP file",
        "diagPackFail", "Couldn't create the diagnostic package",
        "instDoneS", "All set!`n`n'Chaos Ward' is now on your desktop and in the Start menu.`nYou can delete the setup file.",
        "instUpdDoneS", "Update done!`n`nYour wishes and settings are kept.`nYou can delete the setup file.",
        "instDone", "All set!`n`nThere's a 'Chaos Ward' icon on your desktop now.`nYou can delete the extracted folder.",
        "instUpdDone", "Updated!`n`nThere's a 'Chaos Ward' icon on your desktop.`nYou can delete the extracted folder.",
        "unQ", "Really remove Chaos Ward from this PC?",
        "unBye", "Done. Bye!")
    d := (IsObject(Cfg) && Cfg.HasOwnProp("Lang") && Cfg.Lang = "en") ? en : de
    s := d.Has(key) ? d[key] : (de.Has(key) ? de[key] : key)
    if IsObject(Cfg) && Cfg.HasOwnProp("Key")
        s := StrReplace(s, "{k}", Cfg.Key)
    return s
}

; ============================================================================
;  Modus "Automatisch": einmal Strg+C, danach liest die App den Tooltip vom
;  Bildschirm mit (Windows-Texterkennung). Es werden KEINE Tasten gedrückt.
;  Sicherheitsregel: Im Zweifel bleibt der Klick gesperrt.
; ============================================================================
StartTrack(item, cat) {
    global Track, ClickX, ClickY
    if !IsObject(cat) {
        Track.Active := false
        return
    }
    names := []
    for n in item.NameLines
        if StrLen(LKey(n)) >= 4
            names.Push(LKey(n))
    frac := [], truth := Map(), sig := ""
    for m in item.Mods {
        if m.Fractured {
            frac.Push(LKey(RegExReplace(m.Norm, "[\d+%.\-]", "")))
            continue
        }
        if m.HasOwnProp("Gid") && !truth.Has(m.Gid) {
            truth[m.Gid] := m.Val
            sig .= m.Gid ":" m.Val "`n"
        }
    }
    Track := {Active: names.Length > 0, Kind: "", Cat: cat.Id, Names: names, FracKeys: frac, Expected: truth.Count
        , Truth: truth, LastSig: SortSig(sig), Thr: Cfg.OcrBest, Alts: OcrAlts([Cfg.OcrBest]), Rect: 0}
    if !Track.Active
        return
    MouseGetPos(&ClickX, &ClickY)
    SetTimer(Calibrate, -80)                     ; Tooltip ist jetzt sichtbar: Erkennung einmessen
}

; Beim Strg+C kennt die App die richtige Antwort -> beste Einstellung für diesen Bildschirm finden
Calibrate() {
    global Track, OcrBusy, OcrCalib
    if !Track.Active || Cfg.Mode != 3
        return
    if OcrBusy {
        SetTimer(Calibrate, -100)
        return
    }
    OcrBusy := true
    best := -1, bestThr := Cfg.OcrBest, bestR := 0, failed := false, tried := []
    for thr in OcrAlts([Cfg.OcrBest], OCR_SETS.Length) {
        try segs := OcrRead(thr, false)
        catch {
            failed := true
            break
        }
        r := AutoEval(segs)
        if r.Status != "ok"
            continue
        score := 0
        for gid, v in r.GidVals
            if Track.Truth.Has(gid) && String(Track.Truth[gid]) = String(v)
                score++
        tried.Push({S: score, T: thr})
        if score > best
            best := score, bestThr := thr, bestR := r
        if score >= Track.Expected
            break
    }
    OcrBusy := false
    ; Reihenfolge fürs Mitlesen: beste zuerst, dann die nächstbesten
    ranked := [bestThr]
    loop tried.Length {
        bi := 0
        for i, x in tried
            if !HasVal(ranked, x.T) && (bi = 0 || x.S > tried[bi].S)
                bi := i
        if bi
            ranked.Push(tried[bi].T)
    }
    Track.Alts := OcrAlts(ranked)
    OcrCalib := Max(best, 0) " / " Track.Expected
    SendOcr()
    if best >= Track.Expected && best > 0 && bestThr != Cfg.OcrBest {
        Cfg.OcrBest := bestThr                       ; für nächstes Mal merken (schneller Start)
        try IniWrite(bestThr, INI, "Einstellungen", "Texterkennung")
    }
    if failed {
        ShowBanner(T("bOcrFail"), T("bCheckSub"), Clr.Amber)
        return
    }
    Track.Thr := bestThr
    if IsObject(bestR) {
        Track.Rect := RectFrom(bestR)
        Track.Fp := TipPrint(Track.Rect)             ; Bild des Tooltips als Vergleich für den nächsten Klick
    }
    if !St.On || St.Hit
        return
    a := Max(best, 0), b := Track.Expected
    if a >= b
        ShowBanner(T("bTrack"), StrReplace(StrReplace(T("bTrackQ"), "{a}", a), "{b}", b), Clr.Green)
    else {
        ShowBanner(T("bWeak"), OcrHasEnglish() ? StrReplace(StrReplace(T("bWeakSub"), "{a}", a), "{b}", b) : T("bNoEnSub"), Clr.Amber)
        SaveDiag("kalibrierung-" a "-von-" b, IsObject(bestR) ? bestR : 0)
    }
}

; ---------------------------------------------------------------------------
;  Änderungs-Erkennung: Nach dem Klick wird ein winziges Abbild des Tooltips (40x48 Felder) alle 15 ms
;  mit dem Stand vor dem Klick verglichen. Gelesen wird erst, wenn sich das Bild geändert hat und
;  ruhig steht. Schneller als eine feste Wartezeit und liest nie den alten Tooltip.
;  Klappt das nicht (kein Ausschnitt bekannt, keine Änderung sichtbar), wie bisher nach fester Zeit.
; ---------------------------------------------------------------------------
WatchStart() {
    global Track
    if !Track.HasOwnProp("Rect") || !IsObject(Track.Rect) {
        SetTimer(AutoCheck.Bind(1), -180)
        return
    }
    ref := Track.HasOwnProp("Fp") && IsObject(Track.Fp) ? Track.Fp : TipPrint(Track.Rect)
    if !IsObject(ref) {
        SetTimer(AutoCheck.Bind(1), -180)
        return
    }
    Track.Watch := {Ref: ref, Prev: 0, T0: A_TickCount, Id: A_TickCount}
    SetTimer(WatchStep.Bind(Track.Watch.Id), -15)
}

WatchStep(id) {
    global WatchSt
    if !St.On || St.Hit || !St.Locked || Cfg.Mode != 3 || !Track.HasOwnProp("Watch") || Track.Watch.Id != id
        return
    w := Track.Watch, ms := A_TickCount - w.T0
    fp := TipPrint(Track.Rect)
    if IsObject(fp) {
        if PrintDiff(fp, w.Ref) >= 12 {                ; deutlich anders als vor dem Klick ...
            if IsObject(w.Prev) && PrintDiff(fp, w.Prev) < 5 {   ; ... und steht ruhig -> jetzt lesen
                WatchSt.N++, WatchSt.Hit++, WatchSt.Ms += ms
                Track.DeleteProp("Watch")
                AutoCheck(1)
                return
            }
        }
        w.Prev := fp
    }
    if ms >= 300 {                                     ; nichts gesehen -> wie bisher lesen und vergleichen
        WatchSt.N++, WatchSt.TO++
        Track.DeleteProp("Watch")
        AutoCheck(1)
        return
    }
    SetTimer(WatchStep.Bind(id), -15)
}

; Abbild des Bereichs: 40x48 Felder, je Feld Helligkeit 0..765 (Windows verkleinert per HALFTONE, das ist schnell)
TipPrint(rc) {
    static FW := 40, FH := 48
    if !IsObject(rc) || rc.W < 20 || rc.H < 20
        return 0
    out := 0
    hdcS := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdc := DllCall("CreateCompatibleDC", "Ptr", hdcS, "Ptr")
    bi := Buffer(40, 0)
    NumPut("UInt", 40, "Int", FW, "Int", -FH, "UShort", 1, "UShort", 32, bi)
    bits := 0
    hbm := DllCall("CreateDIBSection", "Ptr", hdc, "Ptr", bi, "UInt", 0, "Ptr*", &bits, "Ptr", 0, "UInt", 0, "Ptr")
    if hbm {
        old := DllCall("SelectObject", "Ptr", hdc, "Ptr", hbm, "Ptr")
        DllCall("SetStretchBltMode", "Ptr", hdc, "Int", 4)
        if DllCall("StretchBlt", "Ptr", hdc, "Int", 0, "Int", 0, "Int", FW, "Int", FH
            , "Ptr", hdcS, "Int", rc.X, "Int", rc.Y, "Int", rc.W, "Int", rc.H, "UInt", 0x00CC0020) {
            out := []
            loop FW * FH {
                px := NumGet(bits, (A_Index - 1) * 4, "UInt")
                out.Push((px & 0xFF) + ((px >> 8) & 0xFF) + ((px >> 16) & 0xFF))
            }
        }
        DllCall("SelectObject", "Ptr", hdc, "Ptr", old, "Ptr")
        DllCall("DeleteObject", "Ptr", hbm)
    }
    DllCall("DeleteDC", "Ptr", hdc)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcS)
    return out
}

; größter mittlerer Unterschied einer Zeile (eine geänderte Mod-Zeile fällt so deutlich auf)
PrintDiff(a, b) {
    static FW := 40
    if !IsObject(a) || !IsObject(b) || a.Length != b.Length
        return 999
    worst := 0, rowSum := 0
    for i, v in a {
        rowSum += Abs(v - b[i])
        if Mod(i, FW) = 0 {
            worst := Max(worst, rowSum / FW)
            rowSum := 0
        }
    }
    return worst
}

; gibt es diesen Wert für den Mod überhaupt? (Spanne aller Tiers, mit Luft für Qualität und Katalysatoren)
ValuePossible(g, v) {
    lo := "", hi := ""
    for r in g.Ranges
        if IsObject(r) {                              ; manche Bereiche stehen verkehrt herum, z.B. (10-5)
            lo := lo = "" ? Min(r.Lo, r.Hi) : Min(lo, r.Lo, r.Hi)
            hi := hi = "" ? Max(r.Lo, r.Hi) : Max(hi, r.Lo, r.Hi)
        }
    if lo = "" || !IsNumber(v)
        return true                                   ; keine Bereiche bekannt -> nicht prüfen
    span := Max(Abs(lo), Abs(hi))
    return v >= Min(lo * 0.75, lo - 1) && v <= hi + Max(2, span * 0.5)
}

AutoCheck(attempt) {
    global Track, OcrBusy
    if !St.On || St.Hit || !St.Locked || Cfg.Mode != 3
        return
    if OcrBusy {
        SetTimer(AutoCheck.Bind(attempt), -60)
        return
    }
    ; Einstellungen abwechseln: beste Schwelle zuerst, dann Alternativen; später auch ohne Ausschnitt
    thr := Track.Alts[Mod(attempt - 1, 3) + 1]
    useRect := attempt <= 5
    OcrBusy := true
    try segs := OcrRead(thr, useRect)
    catch {
        OcrBusy := false
        ShowBanner(T("bOcrFail"), T("bCheckSub"), Clr.Amber)
        return
    }
    r := AutoEval(segs)
    if r.Status != "ok" || r.Unsure {
        ; nur wenn unsicher: sofort eine zweite Variante lesen und beide zusammenlegen
        alt := thr = Track.Alts[1] ? Track.Alts[2] : Track.Alts[1]
        try {
            segs2 := OcrRead(alt, useRect)
            for sg in segs2
                segs.Push(sg)
            LastOcr.Segs := segs
            r := AutoEval(segs)
        }
    }
    OcrBusy := false
    if r.Status = "ok" && r.Hits > 0 && r.Hits >= GetNeed(Track.Cat) {
        if Track.Kind = "dv"
            TriggerHit(r.Hits, "dv", "", r.HasOwnProp("Vals") ? ReelDv(r.Vals) : 0)
        else
            TriggerHit(r.Hits, "", "", r.HasOwnProp("Reel") ? r.Reel : 0)
        return
    }
    if r.Status = "ok" && r.Groups >= Track.Expected
        Track.Rect := RectFrom(r)                  ; Tooltip-Position mitführen
    if r.Status = "ok" && !r.Unsure && IsObject(Track.Rect)
        Track.Fp := TipPrint(Track.Rect)           ; so sieht der Tooltip jetzt aus (Vergleich für den nächsten Klick)
    changed := r.Status = "ok" && r.Sig != Track.LastSig
    if r.Status = "ok" && !r.Unsure && changed {
        Track.LastSig := r.Sig
        Unlock()
        return
    }
    if attempt < 9 {
        SetTimer(AutoCheck.Bind(attempt + 1), -90)
        return
    }
    if r.Status = "ok" && !r.Unsure && !changed
        CountOrb(-1)                                ; nichts geändert -> Orb wurde nicht verbraucht
    else
        SaveDiag(r.Status != "ok" ? "kein-tooltip" : "unsicher", r)
    if Cfg.UnsureRelease && Track.Kind != "dv" {   ; Divine: nie unsicher freigeben (Treffer sind selten und wertvoll)
        if r.Status = "ok"
            Track.LastSig := r.Sig
        St.Locked := false
        ShowBanner(T("bReleased"), T("bReleasedSub"), Clr.Amber)
        return
    }
    msg := r.Status != "ok" ? T("bNoTip") : r.Unsure ? T("bUnsure") : T("bNoChange")
    ShowBanner(msg, T("bCheckSub"), Clr.Amber)     ; bleibt gesperrt
}

; Ausschnitt um den Tooltip (aus der letzten guten Erkennung) mit Rand
RectFrom(r) {
    x1 := 99999, x2 := -99999, y2 := 0, h := r.Head.H
    for sg in r.TipSegs
        x1 := Min(x1, sg.X1), x2 := Max(x2, sg.X2), y2 := Max(y2, sg.Y + sg.H)
    return {X: Round(x1 - 4 * h), Y: Round(r.Head.Y - 7 * h), W: Round(x2 - x1 + 8 * h), H: Round(y2 - r.Head.Y + 16 * h)}
}

OcrRead(thr, useRect) {
    global LastOcr
    mx := ClickX, my := ClickY
    l := 0, mTop := 0, rr := A_ScreenWidth, bb := A_ScreenHeight
    loop MonitorGetCount() {
        MonitorGet(A_Index, &ml, &mt, &mr, &mbot)
        if mx >= ml && mx < mr && my >= mt && my < mbot {
            l := ml, mTop := mt, rr := mr, bb := mbot
            break
        }
    }
    maxDim := OCR.MaxImageDimension - 8
    if useRect && IsObject(Track.Rect) {
        x1 := Max(l, Track.Rect.X), y1 := Max(mTop, Track.Rect.Y)
        w := Min(rr, Track.Rect.X + Track.Rect.W) - x1, h := Min(bb, Track.Rect.Y + Track.Rect.H) - y1
        scale := Max(1, Min(2.6, maxDim / Max(w, h, 1)))  ; kleiner Ausschnitt -> stärker vergrößern
    } else {
        mh := bb - mTop
        scale := mh <= 1100 ? 1.6 : mh <= 1500 ? 1.25 : 1
        maxPx := Floor(maxDim / scale)
        w := Min(rr - l, maxPx)
        x1 := Max(l, Min(mx - w // 2, rr - w))
        y2 := Min(bb, my + mh // 5)
        h := Min(y2 - mTop, maxPx)
        y1 := y2 - h
    }
    if w < 40 || h < 40
        return []
    OcrFilter(thr >= 1000)
    res := OCR.FromRect(Integer(x1), Integer(y1), Integer(w), Integer(h), {lang: OcrLanguage(), scale: scale, monochrome: Mod(thr, 1000), invertcolors: 1})
    own := OwnOverlayRects()                    ; Text in den eigenen Fenstern ignorieren (statt sie auszublenden -> kein Flackern)
    words := []
    for wd in res.Words {
        cx := wd.x + wd.w / 2, cy := wd.y + wd.h / 2, mine := false
        for rc in own
            if cx >= rc.X && cx < rc.X + rc.W && cy >= rc.Y && cy < rc.Y + rc.H {
                mine := true
                break
            }
        if !mine
            words.Push({T: wd.Text, X: wd.x, Y: wd.y, W: wd.w, H: wd.h})
    }
    segs := BuildSegments(words)
    LastOcr := {X: Integer(x1), Y: Integer(y1), W: Integer(w), H: Integer(h), Thr: thr, Segs: segs}
    return segs
}

; Kopfzeile erkennen. Die Texterkennung legt Name + Grundtyp manchmal in EINE Zeile
; ("HEADHUNTER HEAVY BELT") -> enthaltener Name zählt dann auch als Treffer.
HeadSim(k, n) {
    v := Sim(k, n)
    if StrLen(n) >= 6 && StrLen(k) <= 3 * StrLen(n) && InStr(k, n)
        v := Max(v, 0.9)
    return v
}

; bis zu n Einstellungen: zuerst die übergebenen, dann der Rest aus OCR_SETS (ohne Doppelte)
OcrAlts(first, n := 3) {
    out := []
    for x in first
        if HasVal(OCR_SETS, x) && !HasVal(out, x) && out.Length < n
            out.Push(x)
    for x in OCR_SETS
        if !HasVal(out, x) && out.Length < n
            out.Push(x)
    return out
}

; Filter vor der Texterkennung umschalten: Farbkanal (max R/G/B) oder Helligkeit (Original von OCR.ahk)
OcrFilter(useMax) {
    global OcrMaxMCode, OcrLumMCode
    static tried := false
    if !tried {
        tried := true
        OcrLumMCode := OCR.MonochromeMCode
        if A_PtrSize = 8                             ; geprüfter x64-Code, Quelle: tools/mcode/maxchan.c
            try OcrMaxMCode := OCR.MCode("2,x64:VUHB6QJXRInHQQ+v+VZTi3QkSIX/dFlIictBidNFMcCF0nRcDx9AAESJwQ8fRAAAichMjRSDQYsCicIPtuwPtsDB6hAPttI56g9C1TnQD0LCOcYZwIPBAQ0AAAD/QYkCQTnLdctFAchFActBOfhyuFsxwF5fXcNmDx+EAAAAAABFAchBOfhz6EUByEE5+HLw694=")
    }
    OCR.MonochromeMCode := (useMax && OcrMaxMCode) ? OcrMaxMCode : OcrLumMCode
}

OcrLanguage() {
    static lang := ""
    if lang != ""
        return lang
    lang := "FirstFromAvailableLanguages"
    langs := ""
    try langs := OCR.GetAvailableLanguages()
    for l in StrSplit(langs, "`n", "`r")
        if SubStr(l, 1, 3) = "en-" {
            lang := l
            break
        }
    return lang
}

; Wörter -> Zeilen -> Abschnitte (zwei Tooltips nebeneinander werden getrennt)
BuildSegments(words) {
    lines := []
    for i in SortIdx(words, (w) => w.Y + w.H / 2) {
        w := words[i], cy := w.Y + w.H / 2, placed := false
        for ln in lines {
            if Abs(ln.Cy - cy) < 0.6 * Max(ln.H, w.H) {
                ln.W.Push(w), ln.H := Max(ln.H, w.H), placed := true
                break
            }
        }
        if !placed
            lines.Push({Cy: cy, H: w.H, W: [w]})
    }
    segs := []
    for ln in lines {
        cur := []
        for i in SortIdx(ln.W, (w) => w.X) {
            w := ln.W[i]
            if cur.Length {
                last := cur[cur.Length]
                if w.X - (last.X + last.W) > 2.2 * ln.H {
                    segs.Push(MakeSeg(cur)), cur := []
                }
            }
            cur.Push(w)
        }
        if cur.Length
            segs.Push(MakeSeg(cur))
    }
    return segs
}

MakeSeg(ws) {
    x1 := 99999, x2 := -99999, y := 99999, h := 0, txt := ""
    for w in ws {
        x1 := Min(x1, w.X), x2 := Max(x2, w.X + w.W), y := Min(y, w.Y), h := Max(h, w.H)
        txt .= (txt = "" ? "" : " ") w.T
    }
    return {Text: txt, Cx: (x1 + x2) / 2, X1: x1, X2: x2, Y: y, H: h}
}

SortIdx(arr, keyFn) {
    if arr.Length = 0
        return []
    s := ""
    for i, v in arr
        s .= Round(keyFn(v) * 10) "`t" i "`n"
    out := []
    for line in StrSplit(Sort(RTrim(s, "`n"), "N"), "`n") {
        p := StrSplit(line, "`t")
        if p.Length = 2
            out.Push(Integer(p[2]))
    }
    return out
}

AutoEval(segs) {
    if Track.Kind = "mb"
        return AutoEvalMB(segs)
    if Track.Kind = "dv"
        return AutoEvalDV(segs)
    if !DB.CatById.Has(Track.Cat)
        return {Status: "nocat"}
    cat := DB.CatById[Track.Cat]
    ; 1) Kopfzeile des gehoverten Items (Name vom Strg+C)
    best := 0, head := 0
    for sg in segs {
        k := LKey(sg.Text)
        if StrLen(k) < 4
            continue
        for n in Track.Names {
            v := HeadSim(k, n)
            if v > best
                best := v, head := sg
        }
    }
    if best < 0.7
        return {Status: "nohead"}
    ; 2) nur Zeilen, die mittig unter dieser Kopfzeile stehen (Tooltip-Zeilen sind zentriert)
    lines := [], tip := []
    for sg in segs {
        if Abs(sg.Cx - head.Cx) > 2.0 * head.H || sg.Y < head.Y - 3 * head.H
            continue
        tip.Push(sg)
        k := LKey(sg.Text)
        if StrLen(k) < 6 || IsPropLine(sg.Text)     ; "Critical Hit Chance: 9.03%" ist eine Eigenschaft, kein Mod
            continue
        frac := false
        for fk in Track.FracKeys
            if Sim(k, fk) >= 0.85
                frac := true
        if !frac
            lines.Push({Text: sg.Text, K: k})
    }
    ; 3) Gruppen zuordnen (alle Zeilen einer Gruppe müssen da sein, Hybride zuerst)
    w := GetWishes(cat.Id)
    full := Map(), partial := Map(), sortStr := ""
    for gid in cat.Gids {
        gk := GroupKeys(DB.Groups[gid])
        idx := [], worst := 1
        for pk in gk {
            bs := 0, bi := 0
            for i, ln in lines {
                if Aliases.Has(ln.K) && Aliases[ln.K] = gid && pk = gk[1] {
                    v := 1                         ; gelernte Schreibweise
                } else {
                    if Abs(StrLen(ln.K) - StrLen(pk)) > Max(StrLen(ln.K), StrLen(pk)) * 0.35
                        continue
                    v := Sim(ln.K, pk)
                }
                if v > bs
                    bs := v, bi := i
            }
            idx.Push(bi), worst := Min(worst, bs)
        }
        if worst >= 0.82 {
            full[gid] := {Idx: idx}
            sortStr .= Format("{:02}{:04}", 10 - gk.Length, 1000 - Round(worst * 1000)) "`t" gid "`n"
        } else if worst >= 0.65 && w.Has(gid) {
            partial[gid] := 1
        }
    }
    owner := Map(), groups := []
    if sortStr != "" {
        for line in StrSplit(Sort(RTrim(sortStr, "`n")), "`n") {
            gid := StrSplit(line, "`t")[2]
            free := true
            for i in full[gid].Idx
                if owner.Has(i)
                    free := false
            if !free
                continue
            for i in full[gid].Idx
                owner[i] := gid
            groups.Push(gid)
        }
    }
    ; 4) Wünsche prüfen
    hits := 0, unsure := false, sig := "", vals := Map(), hitG := Map()
    for gid in groups {
        g := DB.Groups[gid]
        v := VoteNumber(g, gid, lines, owner)
        if v != "" && !ValuePossible(g, v) {           ; Wert gibt es für diesen Mod nicht -> falsch gelesen
            v := ""
            unsure := true
        }
        vals[gid] := v
        sig .= gid ":" v "`n"
        if !w.Has(gid)
            continue
        mn := w[gid]
        tierN := (v = "") ? 0 : TierOf(g, v)
        h0 := hits
        if mn = "" {
            hits++
        } else if RegExMatch(mn, "^T(\d+)$", &tm) {
            if tierN = 0
                unsure := true
            else if tierN <= Integer(tm[1])
                hits++
        } else if v = "" {
            unsure := true
        } else if v >= mn {
            hits++
        }
        if hits > h0
            hitG[gid] := tierN
    }
    for gid in partial
        if !vals.Has(gid)
            unsure := true
    if groups.Length < Track.Expected
        unsure := true
    ; eigene Text-Wünsche
    ruleHit := 0
    for i, ln in lines
        for rl in Rules {
            rk := LKey(rl.Text)
            if StrLen(rk) >= 4 && InStr(ln.K, rk) {
                if rl.Op = "" || CompareOk(OcrNumber(ln.Text), rl.Op, rl.Val) {
                    hits++
                    if !ruleHit
                        ruleHit := i
                }
                break
            }
        }
    ; 5) Walze für die Treffer-Leiste: Mod-Zeilen in Tooltip-Reihenfolge, Treffer = erste Wunsch-Zeile
    reelL := [], reelT := 0, reelS := "", ord := "", used := Map()
    for gid in groups
        ord .= Format("{:03}", full[gid].Idx[1]) "`t" gid "`n"
    if ord != ""
        for row in StrSplit(Sort(RTrim(ord, "`n")), "`n") {
            gid := StrSplit(row, "`t")[2], li := full[gid].Idx[1], used[li] := 1
            reelL.Push(Trim(lines[li].Text))
            if hitG.Has(gid) && !reelT
                reelT := reelL.Length, reelS := (hitG[gid] ? "T" hitG[gid] "  " : "") ShortMod(lines[li].Text)
        }
    if !reelT && ruleHit {
        if !used.Has(ruleHit)
            reelL.Push(Trim(lines[ruleHit].Text))
        for j, x in reelL
            if x = Trim(lines[ruleHit].Text)
                reelT := j, reelS := ShortMod(x)
    }
    return {Status: "ok", Hits: hits, Unsure: unsure, Sig: SortSig(sig), Groups: groups.Length
        , GidVals: vals, Head: head, TipSegs: tip, Reel: ReelMake(reelL, reelT, reelS)}
}

SortSig(s) => s = "" ? "" : Sort(RTrim(s, "`n"))

LKey(s) => RegExReplace(StrLower(s), "[^a-z]")

GroupKeys(g) {
    if !g.HasOwnProp("Keys") {
        gk := []
        for part in StrSplit(g.Text, " / ")
            gk.Push(LKey(RegExReplace(part, "\([^)]*\)")))
        g.Keys := gk
    }
    return g.Keys
}

; Zahl aus einer gelesenen Zeile (typische Lesefehler in Zahlen reparieren: O->0, l->1, S->5, B->8)
OcrToken(s) {
    pos := 1
    while pos := RegExMatch(s, "[+\-]?[0-9OolIS|B.]+%?", &m, pos) {
        pos += StrLen(m[0])
        if RegExMatch(m[0], "\d")
            return m[0]
    }
    return ""
}

OcrNumber(s) {
    tok := OcrToken(s)
    if tok != "" && NumFixes.Has(tok)
        return NumFixes[tok]
    pos := 1
    while pos := RegExMatch(s, "[+\-]?[0-9OolIS|B.]+%?", &m, pos) {
        tok := m[0]
        pos += StrLen(tok)
        if !RegExMatch(tok, "\d")
            continue
        for a, b in Map("O", "0", "o", "0", "l", "1", "I", "1", "|", "1", "S", "5", "B", "8")
            tok := StrReplace(tok, a, b, true)
        if RegExMatch(tok, "\d+(?:\.\d+)?", &n)
            return n[0] + 0
    }
    return ""
}

Sim(a, b) => 1 - Lev(a, b) / Max(StrLen(a), StrLen(b), 1)

Lev(a, b) {
    la := StrLen(a), lb := StrLen(b)
    if !la
        return lb
    if !lb
        return la
    ac := StrSplit(a), bc := StrSplit(b)
    prev := []
    loop lb + 1
        prev.Push(A_Index - 1)
    loop la {
        i := A_Index, ai := ac[i]
        cur := [i]
        loop lb {
            j := A_Index
            cur.Push(Min(prev[j + 1] + 1, cur[j] + 1, prev[j] + (ai == bc[j] ? 0 : 1)))
        }
        prev := cur
    }
    return prev[lb + 1]
}

; ============================================================================
;  Orb-Zähler und Ziel-Fenster im Spiel
; ============================================================================
CountOrb(d) {
    Stats.Session := Max(0, Stats.Session + d)
    Stats.Total := Max(0, Stats.Total + d)
    Stats.SinceHit := Max(0, Stats.SinceHit + d)
    UpdateCounts()
    SetTimer(PushStats, -300)
    SetTimer(SaveStats, -3000)
}

RecordHit() {
    name := LastItemName != "" ? LastItemName : Cfg.ActiveCat
    Stats.History.InsertAt(1, {T: FormatTime(, "dd.MM. HH:mm"), Name: name, Orbs: Stats.SinceHit})
    while Stats.History.Length > 30
        Stats.History.Pop()
    Stats.SinceHit := 0
    StatsChanged()
}

StatsChanged() {
    UpdateCounts()
    PushStats()
    SaveStats()
}

PushStats() {
    hist := []
    for h in Stats.History
        hist.Push(Map("t", h.T, "name", h.Name, "orbs", h.Orbs))
    WebPost(Map("type", "stats", "session", Stats.Session, "total", Stats.Total, "since", Stats.SinceHit, "history", hist))
}

LoadStats() {
    v := IniRead(INI, "Statistik", "Gesamt", "0")
    Stats.Total := IsInteger(v) ? Integer(v) : 0
    txt := ""
    try txt := FileRead(HITS_FILE, "UTF-8")
    for line in StrSplit(txt, "`n", "`r") {
        p := StrSplit(line, "`t")
        if p.Length >= 3 && IsInteger(p[3])
            Stats.History.Push({T: p[1], Name: p[2], Orbs: Integer(p[3])})
    }
}

SaveStats() {
    try {
        IniWrite(Stats.Total, INI, "Statistik", "Gesamt")
        out := ""
        for h in Stats.History
            out .= h.T "`t" StrReplace(h.Name, "`t", " ") "`t" h.Orbs "`n"
        f := FileOpen(HITS_FILE, "w", "UTF-8")
        f.Write(out)
        f.Close()
    }
}

CountText() => StrReplace(StrReplace(StrReplace(T("pCount"), "{s}", Stats.SinceHit), "{n}", Stats.Session), "{t}", Stats.Total)

UpdateCounts() {
    if IsObject(TargetG) && TargetCtl.HasOwnProp("Count")
        try TargetCtl.Count.Text := CountText()
}

TierLabel(mn) {
    if mn = ""
        return T("tAny")
    if RegExMatch(mn, "^T(\d+)$", &m)
        return m[1] = "1" ? "T1" : StrReplace(T("tUpTo"), "{n}", m[1])
    return ">= " mn
}

; ============================================================================
;  Fenster im Spiel verschieben: Platzhalter zum Ziehen, Position wird als
;  Anteil des Bildschirms gespeichert (passt auch nach Auflösungswechsel).
;  Anker: Meldung/Treffer-Leiste = Oberkante Mitte, Item-Anzeige = Oberkante rechts
; ============================================================================
PosAnchor(key) {
    v := Cfg.HasOwnProp("Pos" key) ? Cfg.%"Pos" key% : ""
    if !RegExMatch(v, "^([\d.]+),([\d.]+)$", &rm)
        return 0
    m := GameMon()
    return {X: m.L + Round(rm[1] * m.W), Y: m.T + Round(rm[2] * m.H)}
}

PlaceDefaults() {
    m := GameMon()
    return Map("Banner", {X: m.L + m.W // 2, Y: m.T + OvPx(30), W: OvPx(460), H: OvPx(66)}
        , "Hit", {X: m.L + m.W // 2, Y: m.T + HitBarDefaultTop(m), W: OvPx(720), H: OvPx(168)}
        , "Item", {X: m.L + m.W - OvPx(40), Y: m.T + OvPx(120), W: OvPx(440), H: OvPx(260)})
}

; Oberkante der sichtbaren Treffer-Leiste (Standard), relativ zum Monitor
HitBarDefaultTop(m) => Round(m.H * 0.06) + OvPx(35)

; ----------------------------------------------------------------------------
;  Monitor des Spiels (dort erscheinen alle Anzeigen) + Größenfaktor
; ----------------------------------------------------------------------------
GameMon() {
    static last := 0, lastTick := 0
    if IsObject(last) && A_TickCount - lastTick < 1500
        return last
    hwnd := GameWindow(), cx := "", cy := ""
    if hwnd {
        try {
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
            cx := wx + ww // 2, cy := wy + wh // 2
        }
    }
    if cx = "" && IsObject(last)                 ; Spiel gerade nicht gefunden -> letzter bekannter Monitor
        return last
    if cx = ""
        MouseGetPos(&cx, &cy)
    m := 0
    loop MonitorGetCount() {
        MonitorGet(A_Index, &ml, &mt, &mr, &mbot)
        if cx >= ml && cx < mr && cy >= mt && cy < mbot {
            m := {L: ml, T: mt, W: mr - ml, H: mbot - mt, N: A_Index}
            break
        }
    }
    if !m {
        MonitorGet(MonitorGetPrimary(), &ml, &mt, &mr, &mbot)
        m := {L: ml, T: mt, W: mr - ml, H: mbot - mt, N: MonitorGetPrimary()}
    }
    last := m, lastTick := A_TickCount
    return m
}

GameWindow() {
    try {
        if (h := WinExist("ahk_class POEWindowClass"))
            return h
        for exe in ["PathOfExile.exe", "PathOfExileSteam.exe", "PathOfExile_x64.exe", "PathOfExile_x64Steam.exe", "PathOfExile_KG.exe", "PathOfExile_x64_KG.exe", "PathOfExileEGS.exe"]
            if (h := WinExist("ahk_exe " exe))
                return h
    }
    return 0
}

; Anzeigen wachsen mit der Monitorhöhe wie die Spiel-Oberfläche (1080p = 1, 1440p = 1,33, 4K = 2)
OvScale() => Max(0.75, Min(2.5, GameMon().H / 1080))
OvPx(n) => Round(n * OvScale())
; Schriftgröße in Punkt so, dass sie unabhängig von der Windows-Skalierung n*OvScale Pixel@96dpi entspricht
FS(n) => "s" Max(6, Round(n * OvScale() * 96 / A_ScreenDPI))

PlaceStart() {
    global PlaceGuis
    PlaceStop()
    if St.On || St.Hit                          ; sonst würde die Klick-Sperre das Ziehen blockieren
        ToggleGuard()
    SetTimer(HideBanner, 0)
    HideBanner(), HideItemNow(), HideHitBar()
    PlaceGuis := Map()
    names := Map("Banner", T("plBanner"), "Hit", T("plHit"), "Item", T("plItem"))
    for key, d in PlaceDefaults() {
        pt := PosAnchor(key)
        ax := pt ? pt.X : d.X, ay := pt ? pt.Y : d.Y
        g := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale")
        g.BackColor := Clr.Panel2
        g.MarginX := OvPx(16), g.MarginY := OvPx(12)
        OvFont(g, FS(13) " w600 c" Clr.Ward2, , "✥  " names[key])
        g.AddText("xm ym w" d.W - OvPx(32) " +0x80", "✥  " names[key])
        OvFont(g, FS(9) " w400 c" Clr.Muted, , T("plDrag"))
        g.AddText("xm y+" OvPx(4) " w" d.W - OvPx(32) " +0x80", T("plDrag"))
        if key = "Hit" {
            OvFont(g, FS(10) " w600 c" Clr.Text, , "✔")
            b1 := g.AddButton("xm y+" OvPx(14) " w" OvPx(150) " h" OvPx(32) " Default", "✔  " T("plDone"))
            b1.OnEvent("Click", (*) => PlaceSave())
            b2 := g.AddButton("x+" OvPx(10) " yp w" OvPx(150) " h" OvPx(32), "↺  " T("plReset"))
            b2.OnEvent("Click", (*) => PlaceReset(true))
        }
        m := GameMon()
        x := key = "Item" ? ax - d.W : ax - d.W // 2
        x := Max(m.L, Min(m.L + m.W - d.W, x)), ay := Max(m.T, Min(m.T + m.H - d.H, ay))
        g.Show("NA x" x " y" ay " w" d.W " h" d.H)
        try WinSetTransparent(225, "ahk_id " g.Hwnd)
        RoundCorners(g.Hwnd)
        PlaceGuis[key] := g
    }
    OnMessage(0x201, PlaceDrag)
}

PlaceDrag(wParam, lParam, msg, hwnd) {
    if !IsObject(PlaceGuis) || PlaceGuis.Count = 0
        return
    root := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
    for key, g in PlaceGuis
        if g.Hwnd = root {
            try {
                if GuiCtrlFromHwnd(hwnd).Type = "Button"   ; Knöpfe normal klicken lassen
                    return
            }
            PostMessage(0xA1, 2, 0, , "ahk_id " root)      ; Fenster ziehen
            return 0
        }
}

PlaceSave() {
    for key, g in PlaceGuis {
        g.GetPos(&x, &y, &w, &h)
        ax := key = "Item" ? x + w : x + w // 2
        m := GameMon()
        v := Format("{:.4f},{:.4f}", Max(0, Min(1, (ax - m.L) / m.W)), Max(0, Min(1, (y - m.T) / m.H)))
        Cfg.%"Pos" key% := v
        try IniWrite(v, INI, "Positionen", key = "Banner" ? "Meldung" : key = "Item" ? "ItemAnzeige" : "TrefferLeiste")
    }
    PlaceStop()
    ShowBanner(T("plSaved"), "", Clr.Green)
    SetTimer(HideBanner, -1800)
}

PlaceReset(reopen) {
    for key in ["Banner", "Item", "Hit"] {
        Cfg.%"Pos" key% := ""
        try IniWrite("", INI, "Positionen", key = "Banner" ? "Meldung" : key = "Item" ? "ItemAnzeige" : "TrefferLeiste")
    }
    if reopen
        PlaceStart()
}

PlaceStop() {
    global PlaceGuis
    OnMessage(0x201, PlaceDrag, 0)
    if IsObject(PlaceGuis)
        for key, g in PlaceGuis
            try g.Destroy()
    PlaceGuis := Map()
}

; Bildschirm-Rechtecke der eigenen Anzeigen (deren Text liest die Erkennung nicht mit)
OwnOverlayRects() {
    out := []
    for g in [Banner, ItemG, HitBarG] {
        if !IsObject(g)
            continue
        try {
            g.GetPos(&x, &y, &w, &h)
            if IsObject(HitBarG) && g = HitBarG
                x := HitBarPos.X, y := HitBarPos.Y, w := HitBarPos.W, h := HitBarPos.H
            out.Push({X: x, Y: y, W: w, H: h})
        }
    }
    return out
}

; ============================================================================
;  Setup-Erkennung: Spielsprache, Spiel als Administrator, echtes Vollbild
; ============================================================================

; Item-Text aus dem Spiel? Englisch -> ok. Andere Sprache -> Hinweis (Mod-Daten gibt es nur auf Englisch).
CheckGameLang(txt) {
    global GameLang
    static lastWarn := 0
    if !InStr(txt, "--------")
        return true                              ; kein Item-Text, normal weiter (ParseItem entscheidet)
    first := Trim(StrSplit(StrReplace(txt, "`r"), "`n")[1])
    if RegExMatch(first, "^(Item Class|Rarity)\s*:") {
        GameLang := "en"
        return true
    }
    if !RegExMatch(first, "^[^:]{3,40}:\s*\S")  ; sieht nicht nach einem Item aus
        return true
    GameLang := "other"
    if A_TickCount - lastWarn > 20000 || !lastWarn {
        lastWarn := A_TickCount
        ShowBanner(T("bLang"), T("bLangSub"), Clr.Amber)
        SetTimer(HideBanner, -7000)
    }
    return false
}

; 1 = Spiel läuft als Administrator, 0 = nein, -1 = unbekannt
GameElevated() {
    hwnd := GameWindow()
    if !hwnd
        return -1
    pid := 0
    try pid := WinGetPID("ahk_id " hwnd)
    if !pid
        return -1
    hp := DllCall("OpenProcess", "UInt", 0x1000, "Int", 0, "UInt", pid, "Ptr")
    if !hp
        return -1
    tok := 0
    ok := DllCall("advapi32\OpenProcessToken", "Ptr", hp, "UInt", 0x8, "Ptr*", &tok)
    DllCall("CloseHandle", "Ptr", hp)
    if !ok                                       ; Token eines höher berechtigten Prozesses ist nicht lesbar
        return A_IsAdmin ? -1 : 1
    buf := Buffer(4, 0), ret := 0
    ok := DllCall("advapi32\GetTokenInformation", "Ptr", tok, "Int", 20, "Ptr", buf, "UInt", 4, "UInt*", &ret)
    DllCall("CloseHandle", "Ptr", tok)
    return ok ? (NumGet(buf, "UInt") ? 1 : 0) : -1
}

; Läuft gerade ein Spiel im echten (exklusiven) Vollbild? Dort sind Anzeigen unsichtbar.
ExclusiveFullscreen() {
    qs := 0
    try DllCall("shell32\SHQueryUserNotificationState", "Int*", &qs)
    return qs = 3                                ; QUNS_RUNNING_D3D_FULL_SCREEN
}

CheckSetupOnStart() {
    static askedAdmin := false, warnedFs := false
    if !St.On
        return
    if !A_IsAdmin && !askedAdmin && GameElevated() = 1 {
        askedAdmin := true
        if MsgBox(T("mAdmin"), APP, "YesNo Icon! 0x40000") = "Yes"
            RestartAsAdmin()
        return
    }
    if !warnedFs && ExclusiveFullscreen() {
        warnedFs := true
        SoundBeep(660, 120)
        TrayTip(T("bFullscreenSub"), T("bFullscreen"), 0x2)
    }
}

; Systemcheck für die Einstellungen: [Zustand (1 ok, 0 Hinweis, -1 Problem), Titel, Details]
Lg(de, en) => Cfg.Lang = "en" ? en : de

; Windows-Skalierung eines Monitors (DPI), z.B. 144 = 150 %
MonDpi(n) {
    dx := 0, dy := 0
    try {
        MonitorGet(n, &ml, &mt)
        hm := DllCall("MonitorFromPoint", "Int64", ((ml + 1) & 0xFFFFFFFF) | ((mt + 1) << 32), "UInt", 2, "Ptr")
        DllCall("shcore\GetDpiForMonitor", "Ptr", hm, "Int", 0, "UInt*", &dx, "UInt*", &dy)
    }
    return dx ? dx : A_ScreenDPI
}

; Diagnose-Paket: alles, was ich zum Helfen brauche, in eine ZIP-Datei auf dem Desktop
; (Systemcheck, Monitore, Einstellungen, letzte unsichere Lesungen mit Bildausschnitt, Fehler- und Leistungs-Log)
DiagPack() {
    tmp := A_Temp "\ChaosWard-Diagnose"
    zip := A_Desktop "\ChaosWard-Diagnose-" FormatTime(, "yyyy-MM-dd_HH-mm") ".zip"
    try DirDelete(tmp, true)
    DirCreate(tmp)
    txt := "Chaos Ward " APP_VER "`nWindows " A_OSVersion (A_Is64bitOS ? " 64-bit" : " 32-bit") "   Admin: " A_IsAdmin "   Windows-Sprache: " A_Language "`n"
        . "Oberfläche: " UI_MODE "   Modus: " Cfg.Mode "   Treffer-Animation: " Cfg.HitAnim "   Ton: " Cfg.SoundName "`n"
        . "Texterkennung: Filter " Cfg.OcrBest "   letzte Eichung: " OcrCalib "   Sprache: " OcrLanguage() "   Englisch: " (OcrHasEnglish() ? "ja" : "nein") "`n"
        . "Spielsprache laut Strg+C: " GameLang "`n"
        . "Änderungs-Erkennung: " WatchSt.N " Klicks, " WatchSt.Hit " erkannt (Ø " (WatchSt.Hit ? Round(WatchSt.Ms / WatchSt.Hit) : 0) " ms), " WatchSt.TO " ohne sichtbare Änderung`n`nMonitore:`n"
    gm := GameMon()
    loop MonitorGetCount() {
        MonitorGet(A_Index, &ml, &mt, &mr, &mb2)
        txt .= "  " A_Index ": " ml "," mt "  " (mr - ml) "x" (mb2 - mt) "  Skalierung " Round(MonDpi(A_Index) * 100 / 96) "%" (A_Index = gm.N ? "   <- Spiel" : "") "`n"
    }
    txt .= "`nSystemcheck:`n"
    try {
        for it in SysCheck()
            txt .= "  [" (it[1] = 1 ? "ok" : it[1] = 0 ? "info" : "PROBLEM") "] " it[2] ": " it[3] "`n"
    }
    FileAppend(txt, tmp "\system.txt", "UTF-8")
    if FileExist(INI)
        FileCopy(INI, tmp "\Einstellungen.ini")
    if DirExist(DIAG_DIR)
        DirCopy(DIAG_DIR, tmp "\Diagnose", 1)
    q := (x) => "'" StrReplace(x, "'", "''") "'"
    try FileDelete(zip)
    RunWait('powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Compress-Archive -Path ' q(tmp "\*") ' -DestinationPath ' q(zip) ' -Force"', , "Hide")
    try DirDelete(tmp, true)
    return FileExist(zip) ? zip : ""
}

SysCheck() {
    out := []
    ; Windows
    build := 0
    try build := Integer(StrSplit(A_OSVersion, ".")[3])
    win := build >= 22000 ? "Windows 11" : build >= 10240 ? "Windows 10" : "Windows " A_OSVersion
    out.Push([build >= 17763 ? 1 : -1, "Windows", win " (" A_OSVersion ")" (A_Is64bitOS ? "" : Lg(" · 32-Bit", " · 32-bit"))
        . (build >= 17763 ? "" : Lg(" – zu alt für Texterkennung/Oberfläche, Windows 10 ab 1809 nötig", " – too old, Windows 10 1809+ needed"))])
    ; Oberfläche
    out.Push([UI_MODE = "web" ? 1 : 0, Lg("Oberfläche", "Interface"), UI_MODE = "web" ? "WebView2 ✓" : Lg("Ersatz-Oberfläche (WebView2 fehlt)", "Fallback window (WebView2 missing)")])
    ; Texterkennung
    langs := "", ocrOk := false
    try langs := OCR.GetAvailableLanguages(), ocrOk := langs != ""
    en := OcrHasEnglish()
    out.Push([!ocrOk ? -1 : en ? 1 : -1, Lg("Texterkennung", "Text recognition")
        , !ocrOk ? Lg("Windows-Texterkennung nicht verfügbar – nur Modus „Einfach“/„Schlau“", "Windows OCR not available – only Simple/Smart mode")
        : en ? Lg("bereit · Englisch installiert · Filter ", "ready · English installed · filter ") (Cfg.OcrBest >= 1000 ? Lg("Farbkanal ", "colour channel ") Cfg.OcrBest - 1000 : Lg("Helligkeit ", "brightness ") Cfg.OcrBest)
        : Lg("Englisches Sprachpaket fehlt (Windows-Einstellungen → Zeit und Sprache → Sprache hinzufügen → Englisch)", "English language pack missing (Settings → Time & language → Add a language → English)")])
    ; Bildschirm
    m := GameMon()
    dpi := Round(MonDpi(m.N) * 100 / 96)
    out.Push([1, Lg("Bildschirm", "Display"), m.W "×" m.H Lg(" auf Monitor ", " on monitor ") m.N " " Lg("von ", "of ") MonitorGetCount()
        . " · " Lg("Windows-Skalierung ", "Windows scaling ") dpi "% · " Lg("Anzeigen ×", "overlays ×") Format("{:.2f}", OvScale())])
    ; Spiel
    hwnd := GameWindow()
    if !hwnd {
        out.Push([0, Lg("Spiel", "Game"), Lg("Path of Exile 2 läuft gerade nicht – zum Prüfen Spiel starten und „Erneut prüfen“", "Path of Exile 2 isn't running – start it and press “Check again”")])
    } else {
        exe := ""
        try exe := WinGetProcessName("ahk_id " hwnd)
        out.Push([1, Lg("Spiel", "Game"), Lg("gefunden", "found") (exe != "" ? " (" exe ")" : "")])
        el := GameElevated()
        out.Push([el = 1 && !A_IsAdmin ? -1 : 1, Lg("Rechte", "Permissions")
            , el = 1 && !A_IsAdmin ? Lg("Spiel läuft als Administrator, Chaos Ward nicht → Klick-Sperre wirkt NICHT. Chaos Ward als Administrator starten.", "Game runs as administrator, Chaos Ward doesn't → click lock does NOT work. Run Chaos Ward as administrator.")
            : A_IsAdmin ? Lg("Chaos Ward läuft als Administrator ✓", "Chaos Ward runs as administrator ✓") : Lg("passen ✓", "OK ✓"), el = 1 && !A_IsAdmin ? "admin" : ""])
        isFs := ExclusiveFullscreen()
        out.Push([isFs ? -1 : 1, Lg("Anzeigemodus", "Display mode"), isFs ? Lg("Echtes Vollbild erkannt – Anzeigen unsichtbar. Im Spiel „Fenster-Vollbild“ wählen.", "Exclusive fullscreen detected – overlays invisible. Choose “Windowed Fullscreen” in game.") : Lg("Fenster / Fenster-Vollbild ✓", "Windowed / windowed fullscreen ✓")])
    }
    ; Spielsprache
    out.Push([GameLang = "other" ? -1 : GameLang = "en" ? 1 : 0, Lg("Spielsprache", "Game language")
        , GameLang = "en" ? "English ✓" : GameLang = "other" ? Lg("nicht Englisch – im Spiel Optionen → Sprache → English", "not English – in game Options → Language → English") : Lg("noch kein Item mit Strg+C kopiert", "no item copied with Ctrl+C yet")])
    return out
}

RestartAsAdmin() {
    try {
        Run('*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"')
        ExitApp()
    } catch {
        MsgBox(T("mAdminFail"), APP, "Icon! 0x40000")
    }
}

; Das frühere Ziel-Fenster links im Spiel wurde entfernt (es hat beim Mitlesen geflackert).
; Aufrufe bleiben harmlos: räumt nur ein evtl. noch offenes Fenster weg.
RefreshTarget() {
    global TargetG
    if IsObject(TargetG)
        try TargetG.Destroy()
    TargetG := 0
}

GdipStartup() {
    static token := 0
    if token
        return true
    DllCall("LoadLibrary", "Str", "gdiplus", "Ptr")
    si := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
    NumPut("UInt", 1, si)
    DllCall("gdiplus\GdiplusStartup", "UPtr*", &token, "Ptr", si, "Ptr", 0)
    return token != 0
}

LoadHBitmap(file, &w, &h) {
    pBmp := 0, hbm := 0, w := 0, h := 0
    DllCall("gdiplus\GdipCreateBitmapFromFile", "WStr", file, "Ptr*", &pBmp)
    DllCall("gdiplus\GdipGetImageWidth", "Ptr", pBmp, "UInt*", &w)
    DllCall("gdiplus\GdipGetImageHeight", "Ptr", pBmp, "UInt*", &h)
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", pBmp, "Ptr*", &hbm, "UInt", 0)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBmp)
    return hbm
}

ShowLayered(hwnd, hbm, x, y, w, h, alpha := 255) {
    hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
    old := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbm, "Ptr")
    pt := Buffer(8), NumPut("Int", x, "Int", y, pt)
    sz := Buffer(8), NumPut("Int", w, "Int", h, sz)
    src := Buffer(8, 0)
    blend := Buffer(4), NumPut("UChar", 0, "UChar", 0, "UChar", alpha, "UChar", 1, blend)   ; AC_SRC_OVER, Alpha pro Pixel
    ok := DllCall("UpdateLayeredWindow", "Ptr", hwnd, "Ptr", hdcScreen, "Ptr", pt, "Ptr", sz, "Ptr", hdcMem, "Ptr", src, "UInt", 0, "Ptr", blend, "UInt", 2)
    errNo := A_LastError
    DllCall("SelectObject", "Ptr", hdcMem, "Ptr", old, "Ptr")
    DllCall("DeleteDC", "Ptr", hdcMem)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
    if !ok
        throw Error("Fenster zeichnen fehlgeschlagen (Windows-Fehler " errNo ")")
}

; GDI+ meldet Fehler als Zahl statt Ausnahme -> hier sichtbar machen
GpOk(status, what, raise := true) {
    if status != 0 && raise
        throw Error("GDI+ " what " fehlgeschlagen (Status " status ")")
    return status
}

; ============================================================================
;  Bessere Erkennung: Zahlen abstimmen, aus Korrekturen lernen, Diagnose
; ============================================================================
; Alle gelesenen Zeilen dieser Gruppe stimmen über die Zahl ab (bei Uneinigkeit: unklar)
VoteNumber(g, gid, lines, owner) {
    k1 := GroupKeys(g)[1]
    votes := Map(), best := "", bestN := 0, tie := false
    for i, ln in lines {
        if owner.Has(i) && owner[i] != gid
            continue
        isMine := (Aliases.Has(ln.K) && Aliases[ln.K] = gid) || Sim(ln.K, k1) >= 0.82
        if !isMine
            continue
        nv := OcrNumber(ln.Text)
        if nv = ""
            continue
        key := String(nv)
        votes[key] := (votes.Has(key) ? votes[key] : 0) + 1
    }
    for key, n in votes {
        if n > bestN
            best := key, bestN := n, tie := false
        else if n = bestN
            tie := true
    }
    return (bestN = 0 || tie) ? "" : best + 0
}

; Nach Strg+C kennt die App die Wahrheit -> falsch gelesene Schreibweisen merken
LearnFrom(item, cat) {
    if !IsObject(LastOcr) || !LastOcr.HasOwnProp("Segs")
        return
    learned := 0
    for m in item.Mods {
        if m.Fractured || !m.HasOwnProp("Gid")
            continue
        k1 := GroupKeys(DB.Groups[m.Gid])[1]
        best := 0, bl := 0
        for sg in LastOcr.Segs {
            k := LKey(sg.Text)
            if StrLen(k) < 8
                continue
            v := Sim(k, k1)
            if v > best
                best := v, bl := sg
        }
        if !IsObject(bl) || best < 0.7
            continue
        k := LKey(bl.Text)
        ; Sicherheit: die Zeile muss dieser Gruppe am ähnlichsten sein (keine Verwechslung)
        top := 0, topGid := ""
        for gid in cat.Gids {
            v := Sim(k, GroupKeys(DB.Groups[gid])[1])
            if v > top
                top := v, topGid := gid
        }
        if topGid != m.Gid
            continue
        if best < 0.82 && !Aliases.Has(k) {
            Aliases[k] := m.Gid, learned++
        }
        tok := OcrToken(bl.Text)
        ; nur Zahlen mit Lesefehlern (Buchstaben drin) lernen, echte Ziffern nie umbiegen
        if tok != "" && m.Val != "" && RegExMatch(tok, "[OolIS|B]") && !NumFixes.Has(tok) {
            NumFixes[tok] := m.Val, learned++
        }
    }
    if learned {
        SaveLearned()
        ShowBanner(StrReplace(T("bLearned"), "{n}", learned), "", Clr.Green)
    }
}

LoadLearned() {
    txt := ""
    try txt := FileRead(LEARN_FILE, "UTF-8")
    for line in StrSplit(txt, "`n", "`r") {
        p := StrSplit(line, "`t")
        if p.Length < 3
            continue
        if p[1] = "A" && DB.Groups.Has(p[3])
            Aliases[p[2]] := p[3]
        else if p[1] = "N" && IsNumber(p[3])
            NumFixes[p[2]] := p[3] + 0
    }
}

SaveLearned() {
    out := ""
    for k, gid in Aliases
        out .= "A`t" k "`t" gid "`n"
    for tok, v in NumFixes
        out .= "N`t" tok "`t" v "`n"
    try {
        f := FileOpen(LEARN_FILE, "w", "UTF-8")
        f.Write(out)
        f.Close()
    }
}

; Bei unsicherem Lesen: Bildausschnitt + erkannten Text speichern (max. 20 Einträge)
SaveDiag(reason, r := 0) {
    if !Cfg.Diag || !IsObject(LastOcr)
        return
    try {
        DirCreate(DIAG_DIR)
        stamp := FormatTime(, "yyyy-MM-dd_HH-mm-ss") "_" Mod(A_TickCount, 1000)
        base := DIAG_DIR "\" stamp "_" reason
        SaveScreenPng(LastOcr.X, LastOcr.Y, LastOcr.W, LastOcr.H, base ".png")
        txt := "Grund: " reason "`nVersion: " APP_VER "`nItem-Art: " Track.Cat "`nErwartete Mods: " Track.Expected
            . "`nSchwelle: " Mod(LastOcr.Thr, 1000) (LastOcr.Thr >= 1000 ? " (Farbkanal)" : " (Helligkeit)") "   Gemerkt: " Cfg.OcrBest "`nBereich: " LastOcr.X "," LastOcr.Y " " LastOcr.W "x" LastOcr.H "`n"
        if IsObject(r) && r.HasOwnProp("Groups")
            txt .= "Erkannte Mods: " r.Groups "   Treffer: " r.Hits "   Unsicher: " r.Unsure "`n"
        txt .= "`nWünsche:`n"
        if Track.Kind = "dv" {
            txt .= "  Divine-Item: " Dv.Item "   " (Dv.Any ? "eine Regel reicht" : "alle Regeln") "`n"
            for key, rs in Dv.Rules
                for idx, r in rs
                    txt .= "  " key " [Zahl " idx "] " r.Op " " r.Val "`n"
        } else if Track.Kind = "mb" {
            for name, n in Mb.Rules
                txt .= "  " n "x Legacy of " name "`n"
            txt .= "  Beliebig: " Mb.Any "   Effekt: " Mb.Eff "   Jedes Duplikat: " Mb.Dup "   Nicht gewollt: " MbBanText() "`n"
        } else {
            for gid, mn in GetWishes(Track.Cat)
                txt .= "  " (DB.Groups.Has(gid) ? DB.Groups[gid].Text : gid) "   [" mn "]`n"
        }
        txt .= "`nGelesene Zeilen (Text | Mitte-x | y | Höhe):`n"
        for sg in LastOcr.Segs
            txt .= "  " sg.Text "  |  " Round(sg.Cx) " | " Round(sg.Y) " | " Round(sg.H) "`n"
        f := FileOpen(base ".txt", "w", "UTF-8")
        f.Write(txt)
        f.Close()
        ; nur die letzten 20 behalten
        files := ""
        loop files DIAG_DIR "\*.txt"
            files .= A_LoopFileName "`n"
        list := StrSplit(Sort(RTrim(files, "`n")), "`n")
        while list.Length > 20 {
            old := RegExReplace(list.RemoveAt(1), "\.txt$")
            try FileDelete(DIAG_DIR "\" old ".txt")
            try FileDelete(DIAG_DIR "\" old ".png")
        }
    }
}

SaveScreenPng(x, y, w, h, file) {
    GdipStartup()
    hdcS := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdcM := DllCall("CreateCompatibleDC", "Ptr", hdcS, "Ptr")
    hbm := DllCall("CreateCompatibleBitmap", "Ptr", hdcS, "Int", w, "Int", h, "Ptr")
    old := DllCall("SelectObject", "Ptr", hdcM, "Ptr", hbm, "Ptr")
    DllCall("BitBlt", "Ptr", hdcM, "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr", hdcS, "Int", x, "Int", y, "UInt", 0x00CC0020)
    DllCall("SelectObject", "Ptr", hdcM, "Ptr", old, "Ptr")
    pBmp := 0
    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hbm, "Ptr", 0, "Ptr*", &pBmp)
    clsid := Buffer(16, 0)
    DllCall("ole32\CLSIDFromString", "WStr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", clsid)
    DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBmp, "WStr", file, "Ptr", clsid, "Ptr", 0)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBmp)
    DllCall("DeleteObject", "Ptr", hbm)
    DllCall("DeleteDC", "Ptr", hdcM)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcS)
}

; ============================================================================
;  Treffer-Leiste im Slot-Stil (GDI+, echte Transparenz, durchklickbar)
;  Pop-Animation, drehende Lichtstrahlen, Gold-Schrift mit Glanz, Funkeln,
;  Orb-Zähler zählt hoch. Rahmen/Leuchten in der Akzentfarbe des Themes.
; ============================================================================
ShowHitBar(hits, orbs, style := "", sub := "", reel := 0) {
    global HitBarG, HitBarT0, HitBarInfo, HitBarPos
    try {
        HideHitBar()
        if !GdipStartup()
            throw Error("GDI+ konnte nicht gestartet werden")
        hs := OvScale()
        W := Round(900 * hs), H := Round(420 * hs)        ; Zeichenraster 900x420 (Platz für die Strahlen)
        reel := HitReelReady(reel, style, hits)
        if sub = ""
            sub := HitSubText(reel, style, hits)
        HitBarInfo := {Hits: hits, Orbs: orbs, Style: style, Sub: sub, Reel: reel, Ms: 0, Iv: 33, Still: false}
        HitBarG := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x80000 +E0x20 +E0x08000000")
        if !Cfg.StreamVisible
            try DllCall("SetWindowDisplayAffinity", "Ptr", HitBarG.Hwnd, "UInt", 0x11)
        HitBarG.Show("NA x0 y0 w1 h1")
        m := GameMon()
        ; Ankerpunkt = Oberkante Mitte der sichtbaren Leiste (Leiste 168 hoch, mittig im 420er Fenster)
        pt := PosAnchor("Hit")
        if !pt
            pt := {X: m.L + m.W // 2, Y: m.T + HitBarDefaultTop(m)}
        HitBarPos := {X: pt.X - W // 2, Y: pt.Y - Round(126 * hs), W: W, H: H, S: hs}   ; Leiste (168 hoch) sitzt mittig
        HitSurfOpen(W, H)                        ; feste Zeichenfläche (schnell); klappt das nicht -> alter Weg
        HitTimerRes(true)
        HitBarT0 := A_TickCount - (Cfg.HitAnim = "instant" ? Round(HitStill(style) * 1000) : 0)
        HitBarStep()                             ; erster Frame sofort (Fehler fallen hier auf)
        SetTimer(HitBarStep, HitBarInfo.Iv)
        if Cfg.HitBarSecs > 0 && St.Hit             ; Leiste blendet aus, Klick bleibt gesperrt
            SetTimer(HitBarAutoHide, -Cfg.HitBarSecs * 1000)
        return true
    } catch as e {
        LogError("Treffer-Leiste", e)
        HideHitBar()
        return false
    }
}

; ~60 Bilder/s: Windows-Timer für die Dauer der Animation feiner stellen
HitTimerRes(on) {
    static active := false
    if on && !active {
        try DllCall("winmm\timeBeginPeriod", "UInt", 1)
        active := true
    } else if !on && active {
        try DllCall("winmm\timeEndPeriod", "UInt", 1)
        active := false
    }
}

; Eine Zeichenfläche für die ganze Animation: DIB + DC + GDI+-Grafik (statt jedes Bild neu anzulegen)
HitSurfOpen(W, H) {
    global HitSurf
    HitSurfClose()
    try {
        hdcScr := DllCall("GetDC", "Ptr", 0, "Ptr")
        hdc := DllCall("CreateCompatibleDC", "Ptr", hdcScr, "Ptr")
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScr)
        bi := Buffer(40, 0)
        NumPut("UInt", 40, "Int", W, "Int", -H, "UShort", 1, "UShort", 32, bi)
        bits := 0
        hbm := DllCall("CreateDIBSection", "Ptr", hdc, "Ptr", bi, "UInt", 0, "Ptr*", &bits, "Ptr", 0, "UInt", 0, "Ptr")
        if !hbm {
            DllCall("DeleteDC", "Ptr", hdc)
            return false
        }
        old := DllCall("SelectObject", "Ptr", hdc, "Ptr", hbm, "Ptr")
        g := 0
        if DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdc, "Ptr*", &g) || !g {
            DllCall("SelectObject", "Ptr", hdc, "Ptr", old, "Ptr")
            DllCall("DeleteObject", "Ptr", hbm)
            DllCall("DeleteDC", "Ptr", hdc)
            return false
        }
        HitSurf := {W: W, H: H, Hdc: hdc, Hbm: hbm, Old: old, G: g, Bits: bits, Checked: false}
        return true
    }
    HitSurf := 0
    return false
}

HitSurfClose() {
    global HitSurf
    if !IsObject(HitSurf)
        return
    try DllCall("gdiplus\GdipDeleteGraphics", "Ptr", HitSurf.G)
    try DllCall("SelectObject", "Ptr", HitSurf.Hdc, "Ptr", HitSurf.Old, "Ptr")
    try DllCall("DeleteObject", "Ptr", HitSurf.Hbm)
    try DllCall("DeleteDC", "Ptr", HitSurf.Hdc)
    HitSurf := 0
}

; Ein Bild wird nie mittendrin unterbrochen: sonst kann z.B. der Ausblende-Timer die Zeichenfläche
; schließen, während noch gezeichnet wird (v7.0: "Integer has no property Checked")
HitBarStep() {
    prev := A_IsCritical
    Critical
    try {
        HitBarFrame()
    } finally {
        Critical prev
    }
}

HitBarFrame() {
    global HitSurf
    if !IsObject(HitBarG) {
        SetTimer(HitBarStep, 0)
        return
    }
    secs := (A_TickCount - HitBarT0) / 1000
    if HitBarInfo.Still {                        ; Endbild steht: nichts mehr zu tun
        SetTimer(HitBarStep, 0)
        return
    }
    if secs >= HitStill(HitBarInfo.Style)        ; letztes Bild zeichnen, danach still
        HitBarInfo.Still := true, secs := HitStill(HitBarInfo.Style)
    t0 := 0, t1 := 0, fq := 0
    DllCall("QueryPerformanceCounter", "Int64*", &t0)
    try {
        alpha := secs < 0.12 ? Round(255 * secs / 0.12) : 255
        if IsObject(HitSurf) {
            g := HitSurf.G
            DllCall("gdiplus\GdipResetWorldTransform", "Ptr", g)
            DllCall("gdiplus\GdipResetClip", "Ptr", g)
            DllCall("gdiplus\GdipGraphicsClear", "Ptr", g, "UInt", 0)
            HitGfxSetup(g, HitSurf.W)
            DrawHitScene(g, secs, HitBarInfo)
            DllCall("gdiplus\GdipFlush", "Ptr", g, "Int", 1)
            if !IsObject(HitSurf) || !IsObject(HitBarG)    ; inzwischen geschlossen -> nichts mehr anzeigen
                return
            if !HitSurf.Checked {                ; Transparenz wirklich geschrieben? Mitte der Leiste muss deckend sein
                HitSurf.Checked := true
                ca := NumGet(HitSurf.Bits, ((HitSurf.H // 2) * HitSurf.W + HitSurf.W // 2) * 4 + 3, "UChar")
                if ca < 128 {
                    LogError("Treffer-Leiste (schnell)", Error("Alpha in der Mitte = " ca " -> alter Weg"))
                    HitSurfClose()
                    return
                }
            }
            ShowLayeredDC(HitBarG.Hwnd, HitSurf.Hdc, HitBarPos.X, HitBarPos.Y, HitBarPos.W, HitBarPos.H, alpha)
        } else {
            hbm := RenderHitFrame(HitBarPos.W, HitBarPos.H, secs, HitBarInfo)
            if !IsObject(HitBarG) {
                DllCall("DeleteObject", "Ptr", hbm)
                return
            }
            ShowLayered(HitBarG.Hwnd, hbm, HitBarPos.X, HitBarPos.Y, HitBarPos.W, HitBarPos.H, alpha)
            DllCall("DeleteObject", "Ptr", hbm)
        }
    } catch as e {
        if IsObject(HitSurf) {                   ; schneller Weg kaputt -> einmal auf den alten Weg wechseln
            LogError("Treffer-Leiste (schnell)", e)
            HitSurfClose()
            return
        }
        LogError("Treffer-Leiste", e)
        HideHitBar()
        if St.Hit {                              ; Notlösung: einfaches Banner (mit Fehlertext)
            ShowBanner(T("bHit"), StrReplace(T("bHitSub"), "{n}", HitBarInfo.Hits) "`n[v" APP_VER " Notlösung: " HitBarErr "]", Clr.Red, true)
        } else {                                 ; Test-Knopf: Fehler zeigen statt nichts
            ShowBanner("Treffer-Leiste: Fehler (v" APP_VER ")", HitBarErr, Clr.Red)
            SetTimer(HideBanner, -8000)
        }
        return
    }
    ; Bildrate: 30/s; braucht ein Bild zu lange, 20/s (alles ist zeitbasiert, die Bewegung bleibt gleich schnell)
    DllCall("QueryPerformanceCounter", "Int64*", &t1)
    DllCall("QueryPerformanceFrequency", "Int64*", &fq)
    ms := fq ? (t1 - t0) * 1000 / fq : 0
    HitBarInfo.Ms := HitBarInfo.Ms ? HitBarInfo.Ms * 0.8 + ms * 0.2 : ms
    want := HitBarInfo.Ms > 26 ? 50 : 33
    if want != HitBarInfo.Iv {
        HitBarInfo.Iv := want
        SetTimer(HitBarStep, want)
    }
}

ShowLayeredDC(hwnd, hdcSrc, x, y, w, h, alpha := 255) {
    hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
    pt := Buffer(8), NumPut("Int", x, "Int", y, pt)
    sz := Buffer(8), NumPut("Int", w, "Int", h, sz)
    src := Buffer(8, 0)
    blend := Buffer(4), NumPut("UChar", 0, "UChar", 0, "UChar", alpha, "UChar", 1, blend)
    ok := DllCall("UpdateLayeredWindow", "Ptr", hwnd, "Ptr", hdcScreen, "Ptr", pt, "Ptr", sz, "Ptr", hdcSrc, "Ptr", src, "UInt", 0, "Ptr", blend, "UInt", 2)
    errNo := A_LastError
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
    if !ok
        throw Error("Fenster zeichnen fehlgeschlagen (Windows-Fehler " errNo ")")
}

HitBarAutoHide() {
    if !St.Hit || !IsObject(HitBarG)
        return
    HideHitBar()
    ShowBanner("🔒  " T("bHitLocked"), StrReplace(T("bHitLockedSub"), "{k}", Cfg.Key), Clr.Gold)
}

HideHitBar() {
    SetTimer(HitBarAutoHide, 0)
    global HitBarG
    SetTimer(HitBarStep, 0)
    if IsObject(HitBarG) && HitBarInfo.HasOwnProp("Ms") && HitBarInfo.Ms > 0   ; Messwert für Rückfragen: Zeit je Bild
        try {
            DirCreate(DIAG_DIR)
            FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") "  Treffer-Leiste: " Round(HitBarInfo.Ms, 1) " ms je Bild, alle "
                . HitBarInfo.Iv " ms, Maßstab " Round(HitBarPos.S, 2) "`n", DIAG_DIR "\leistung.txt", "UTF-8")
        }
    if IsObject(HitBarG)
        try HitBarG.Destroy()
    HitBarG := 0
    HitSurfClose()
    HitTimerRes(false)
}

LogError(where, e) {
    global HitBarErr
    HitBarErr := e.Message " (" e.What ", Zeile " e.Line ")"
    try {
        DirCreate(DIAG_DIR)
        f := FileOpen(DIAG_DIR "\fehler.txt", "a", "UTF-8")
        f.Write(FormatTime(, "yyyy-MM-dd HH:mm:ss") "  [" where "]  " e.Message "  (" e.What ", Zeile " e.Line ")`n")
        f.Close()
    }
}

; Grundeinstellungen + Maßstab: gezeichnet wird immer im 900x420-Raster, das Bild ist um OvScale() größer
HitGfxSetup(g, W) {
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g, "Int", 4)
    DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", g, "Int", 4)
    DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", g, "Int", 3)      ; bilinear: schnell, für weiche Teile genau richtig
    DllCall("gdiplus\GdipSetCompositingQuality", "Ptr", g, "Int", 1)
    hs := W / 900
    if Abs(hs - 1) > 0.01
        DllCall("gdiplus\GdipScaleWorldTransform", "Ptr", g, "Float", hs, "Float", hs, "Int", 0)
}

; alter Weg (Ersatz): eigenes Bild je Frame -> HBITMAP
RenderHitFrame(W, H, secs, info) {
    pBmp := 0, g := 0
    GpOk(DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", W, "Int", H, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &pBmp), "Bild anlegen")
    if GpOk(DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pBmp, "Ptr*", &g), "Zeichenfläche", false) != 0 {
        DllCall("gdiplus\GdipDisposeImage", "Ptr", pBmp)
        throw Error("GDI+ Zeichenfläche fehlgeschlagen")
    }
    DllCall("gdiplus\GdipGraphicsClear", "Ptr", g, "UInt", 0)
    HitGfxSetup(g, W)
    try DrawHitScene(g, secs, info)
    catch as e {
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", pBmp)
        throw e
    }
    hbm := 0
    gst := DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", pBmp, "Ptr*", &hbm, "UInt", 0)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBmp)
    GpOk(gst, "Bild umwandeln")
    return hbm
}

; Die Szene im Stil "Siegel". Zeichenraster 900x420, Leiste 700x140 mittig.
;  Ablauf (alles hängt nur von secs ab, sieht bei 20 und 30 Bildern/s gleich aus; der Klick ist längst gesperrt):
;   0,00-0,46 s  die 24 Kerben des Siegels leuchten reihum auf, die Kante oben läuft mit
;   0,40-0,56 s  das Schloss dreht sich und rastet ein, die Mitte wird Gold
;   0,50-1,00 s  ein einzelner Ring läuft nach außen, Text und Zähler sind da
;   danach       steht alles still (es wird nichts mehr gezeichnet)
DrawHitScene(g, secs, info) {
    isDv := info.Style = "dv", reel := info.Reel
    cx := 450, cy := 210, pw := 700, ph := 140, px := cx - pw / 2, py := cy - ph / 2
    lock := HitLand(info.Style)
    p := HitEase((secs - 0.04) / 0.42)                  ; Fortschritt der Kerben
    kl := Max(0, Min(1, (secs - (lock - 0.14)) / 0.14)) ; 0..1 Schloss dreht / Mitte wird Gold
    kt := HitEase((secs - 0.26) / 0.26)                 ; Text blendet ein
    rise := 6 * (1 - HitEase(secs / 0.16))              ; Leiste schiebt sich 6 px nach oben ein

    gs := 0
    DllCall("gdiplus\GdipSaveGraphics", "Ptr", g, "UInt*", &gs)
    DllCall("gdiplus\GdipTranslateWorldTransform", "Ptr", g, "Float", 0, "Float", rise, "Int", 0)

    ; --- 1) Fläche mit Schatten (aus dem Zwischenspeicher), Kante oben läuft mit den Kerben
    HitPanelDraw(g, px, py, pw, ph)
    br := Brush(0xFF3A3D42)
    DllCall("gdiplus\GdipFillRectangle", "Ptr", g, "Ptr", br, "Float", px, "Float", py, "Float", pw, "Float", 2)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
    br := Brush(0xFFD6A640)
    DllCall("gdiplus\GdipFillRectangle", "Ptr", g, "Ptr", br, "Float", px, "Float", py, "Float", pw * p, "Float", 2)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)

    ; --- 2) Siegel links
    sx := px + 76, sy := py + ph / 2
    HitSeal(g, sx, sy, p, kl, secs - lock)

    ; --- 3) Text: Kennung, Treffer, Hinweis
    tx := px + 150, ox := px + pw - 132, tw := ox - tx - 18
    ta := Round(255 * kt), dy := 5 * (1 - kt)
    if ta > 0 {
        tier := RegExMatch(reel.HasOwnProp("Sub") ? reel.Sub : "", "^(T\d+)", &tm) ? tm[1] : ""
        lbl := T("hTitle") (isDv ? "  ·  " info.Sub : tier != "" ? "  ·  " tier : "")
        hint := T("hLocked") "  ·  " T("hHint")
        if isDv {
            DrawText(g, lbl, tx, py + 16 + dy, tw, 20, 13, 1, (ta << 24) | 0xF0CF7A, 0, "cond")
            vals := reel.Values, nv := Min(3, vals.Length), y0 := py + 40 + (3 - nv) * 11
            loop nv {
                v := vals[A_Index], yy := y0 + (A_Index - 1) * 23 + dy
                DrawText(g, v.Label, tx, yy, tw - 150, 23, 14.5, 0, (ta << 24) | 0xE7E3DB, 0)
                if v.HasOwnProp("Need") && v.Need != ""
                    DrawText(g, v.Need, tx + tw - 150, yy, 70, 23, 12, 0, (ta << 24) | 0x66635D, 2, "mono")
                DrawText(g, v.Digits v.Unit, tx + tw - 80, yy, 80, 23, 16, 1, (ta << 24) | 0xF0CF7A, 2, "mono")
            }
            DrawText(g, hint, tx, py + ph - 27 + dy, tw, 20, 12, 0, (ta << 24) | 0x9A968E, 0)
        } else {
            main := info.Hits <= 1 && reel.Target <= reel.Lines.Length && info.Style != "mb" ? reel.Lines[reel.Target] : info.Sub
            DrawText(g, lbl, tx, py + 28 + dy, tw, 20, 13, 1, (ta << 24) | 0xF0CF7A, 0, "cond")
            DrawText(g, main, tx, py + 50 + dy, tw, 34, 21, 1, (ta << 24) | 0xE7E3DB, 0)
            DrawText(g, hint, tx, py + 88 + dy, tw, 20, 12.5, 0, (ta << 24) | 0x9A968E, 0)
        }
    }

    ; --- 4) Zähler rechts: Orbs bis zum Treffer, zählt hoch
    pen := PenOf(0xFF2A2C30, 1)
    DllCall("gdiplus\GdipDrawLine", "Ptr", g, "Ptr", pen, "Float", ox, "Float", py + 22, "Float", ox, "Float", py + ph - 22)
    DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
    shown := Round(info.Orbs * HitEase((secs - 0.08) / (lock + 0.04)))
    DrawText(g, String(Max(0, shown)), ox, py + 34, px + pw - ox, 46, shown >= 10000 ? 28 : 34, 1, kl >= 1 ? 0xFFE7E3DB : 0xFF9A968E, 1, "mono")
    DrawText(g, T(isDv ? "hDivines" : "hOrbs"), ox, py + 84, px + pw - ox, 20, 11.5, 1, 0xFF9A968E, 1, "cond")
    DllCall("gdiplus\GdipRestoreGraphics", "Ptr", g, "UInt", gs)
}

; Wann rastet das Schloss ein? (Sound "Siegel" ist genau darauf geschnitten)
HitLand(style) => 0.56
; Ab wann steht das Bild still (danach wird nicht mehr gezeichnet)
HitStill(style) => 1.05

HitEase(x) => 1 - (1 - Max(0, Min(1, x))) ** 3
HitBack(x) {                                            ; Feder-Kurve: schießt leicht über das Ziel hinaus
    x := Max(0, Min(1, x))
    return 1 + 2.7 * (x - 1) ** 3 + 1.7 * (x - 1) ** 2
}

; Das Siegel: Ring, 24 Kerben (leuchten reihum), Scheibe mit Schlüsselloch (dreht sich beim Einrasten)
;  p = Anteil der leuchtenden Kerben, kl = 0..1 Einrasten, after = Sekunden seit dem Einrasten
HitSeal(g, x, y, p, kl, after) {
    RO := 46
    pen := PenOf(kl >= 1 ? 0xFFD6A640 : 0xFF3A3D42, 1.6)
    DllCall("gdiplus\GdipDrawEllipse", "Ptr", g, "Ptr", pen, "Float", x - RO, "Float", y - RO, "Float", RO * 2, "Float", RO * 2)
    DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
    lit := p * 24
    penOff := PenOf(0xFF3A3D42, 2), penOn := PenOf(0xFFF0CF7A, 2)
    for pn in [penOff, penOn]
        DllCall("gdiplus\GdipSetPenStartCap", "Ptr", pn, "Int", 2), DllCall("gdiplus\GdipSetPenEndCap", "Ptr", pn, "Int", 2)
    loop 24 {
        i := A_Index - 1, a := i * 0.2617994
        r1 := Mod(i, 6) ? 35 : 32, r2 := 41
        DllCall("gdiplus\GdipDrawLine", "Ptr", g, "Ptr", i < lit ? penOn : penOff
            , "Float", x + r1 * Sin(a), "Float", y - r1 * Cos(a), "Float", x + r2 * Sin(a), "Float", y - r2 * Cos(a))
    }
    DllCall("gdiplus\GdipDeletePen", "Ptr", penOff), DllCall("gdiplus\GdipDeletePen", "Ptr", penOn)
    ; Scheibe: dunkel -> Gold
    k := kl * kl * (3 - 2 * kl)
    cr := Round(0x1E + (0xD6 - 0x1E) * k), cg := Round(0x1F + (0xA6 - 0x1F) * k), cb := Round(0x22 + (0x40 - 0x22) * k)
    br := Brush(0xFF000000 | (cr << 16) | (cg << 8) | cb), r := 25
    DllCall("gdiplus\GdipFillEllipse", "Ptr", g, "Ptr", br, "Float", x - r, "Float", y - r, "Float", r * 2, "Float", r * 2)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
    ; Schlüsselloch: steht quer und dreht sich beim Einrasten in die Senkrechte
    ang := 90 * (1 - HitBack(kl))
    gs := 0
    DllCall("gdiplus\GdipSaveGraphics", "Ptr", g, "UInt*", &gs)
    DllCall("gdiplus\GdipTranslateWorldTransform", "Ptr", g, "Float", x, "Float", y, "Int", 0)
    DllCall("gdiplus\GdipRotateWorldTransform", "Ptr", g, "Float", ang, "Int", 0)
    path := 0
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &path)
    DllCall("gdiplus\GdipAddPathEllipse", "Ptr", path, "Float", -5.5, "Float", -11, "Float", 11, "Float", 11)
    pts := Buffer(32)
    NumPut("Float", -3, "Float", -3, "Float", 3, "Float", -3, "Float", 4.8, "Float", 12, "Float", -4.8, "Float", 12, pts)
    DllCall("gdiplus\GdipAddPathPolygon", "Ptr", path, "Ptr", pts, "Int", 4)
    DllCall("gdiplus\GdipSetPathFillMode", "Ptr", path, "Int", 1)       ; überlappende Teile bleiben gefüllt
    br := Brush(k > 0.5 ? 0xFF121314 : 0xFF66635D)
    DllCall("gdiplus\GdipFillPath", "Ptr", g, "Ptr", br, "Ptr", path)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
    DllCall("gdiplus\GdipDeletePath", "Ptr", path)
    DllCall("gdiplus\GdipRestoreGraphics", "Ptr", g, "UInt", gs)
    ; ein einzelner Ring läuft nach außen
    if after > 0 && after < 0.5 {
        e := HitEase(after / 0.5), rr := RO + 30 * e
        pen := PenOf((Round(150 * (1 - e)) << 24) | 0xD6A640, 2)
        DllCall("gdiplus\GdipDrawEllipse", "Ptr", g, "Ptr", pen, "Float", x - rr, "Float", y - rr, "Float", rr * 2, "Float", rr * 2)
        DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
    }
}

; Haken als Linie (die mitgelieferte Schrift hat kein ✓)
CheckMark(g, x, y, argb) {
    pen := PenOf(argb, 2.2)
    DllCall("gdiplus\GdipSetPenLineJoin", "Ptr", pen, "Int", 2)
    pts := Buffer(24)
    NumPut("Float", x - 5, "Float", y, "Float", x - 1.5, "Float", y + 3.5, "Float", x + 5, "Float", y - 4, pts)
    DllCall("gdiplus\GdipDrawLines", "Ptr", g, "Ptr", pen, "Ptr", pts, "Int", 3)
    DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
}

; ---------------------------------------------------------------------------
;  Zwischenspeicher: die Fläche mit weichem Schatten wird einmal gezeichnet und danach nur kopiert
; ---------------------------------------------------------------------------
HitCacheGet(key) => HitBmps.Has(key) ? HitBmps[key] : 0

HitCacheNew(key, w, h, &g2) {
    bmp := 0, g2 := 0
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h, "Int", 0, "Int", 0xE200B, "Ptr", 0, "Ptr*", &bmp)
    if !bmp
        throw Error("Zwischenbild nicht anlegbar (" key ")")
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &g2)
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g2, "Int", 4)
    DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", g2, "Int", 7)
    HitBmps[key] := bmp
    return bmp
}

; Schatten + Fläche + Haarlinie, in voller Auflösung (Maßstab der Anzeige)
HitPanelDraw(g, px, py, pw, ph) {
    hs := HitBarPos.HasOwnProp("S") ? HitBarPos.S : 1
    x0 := px - 24, y0 := py - 24, lw := pw + 48, lh := ph + 48
    key := "panel8|" pw "|" ph "|" Round(hs * 100)
    if !(bmp := HitCacheGet(key)) {
        bmp := HitCacheNew(key, Ceil(lw * hs), Ceil(lh * hs), &g2)
        DllCall("gdiplus\GdipScaleWorldTransform", "Ptr", g2, "Float", hs, "Float", hs, "Int", 0)
        DllCall("gdiplus\GdipTranslateWorldTransform", "Ptr", g2, "Float", -x0, "Float", -y0, "Int", 0)
        loop 12 {                                       ; weicher Schatten nach unten
            i := 13 - A_Index
            br := Brush((Round(26 * (1 - i / 13) ** 1.6) << 24) | 0x000000)
            DllCall("gdiplus\GdipFillRectangle", "Ptr", g2, "Ptr", br, "Float", px - i, "Float", py - i + 6, "Float", pw + i * 2, "Float", ph + i * 2)
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
        }
        br := Brush(0xF8121314)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", g2, "Ptr", br, "Float", px, "Float", py, "Float", pw, "Float", ph)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
        pen := PenOf(0xFF2A2C30, 1)
        DllCall("gdiplus\GdipDrawRectangle", "Ptr", g2, "Ptr", pen, "Float", px + 0.5, "Float", py + 0.5, "Float", pw - 1, "Float", ph - 1)
        DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g2)
    }
    DllCall("gdiplus\GdipDrawImageRect", "Ptr", g, "Ptr", bmp, "Float", x0, "Float", y0, "Float", lw, "Float", lh)
}

; Schriften für die Treffer-Leiste: IBM Plex aus ui\fonts (eigene Sammlung), sonst Segoe UI
;  Body = Plex Sans (normal/fett), Semi = Plex Sans SemiBold, Cond = Plex Sans Condensed SemiBold, Mono = Plex Mono SemiBold
HitFonts() {
    static res := 0
    if IsObject(res)
        return res
    coll := 0, fam := Map()
    try {
        DllCall("gdiplus\GdipNewPrivateFontCollection", "Ptr*", &coll)
        if coll {
            for f in ["IBMPlexSans-Regular", "IBMPlexSans-Bold", "IBMPlexSans-SemiBold", "IBMPlexSansCondensed-SemiBold", "IBMPlexMono-SemiBold"]
                if FileExist(A_ScriptDir "\ui\fonts\" f ".ttf")
                    DllCall("gdiplus\GdipPrivateAddFontFile", "Ptr", coll, "WStr", A_ScriptDir "\ui\fonts\" f ".ttf")
            for k, nm in Map("Body", "IBM Plex Sans", "Semi", "IBM Plex Sans SemiBold", "Cond", "IBM Plex Sans Condensed SemiBold", "Mono", "IBM Plex Mono SemiBold") {
                ff := 0
                DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", nm, "Ptr", coll, "Ptr*", &ff)
                if ff
                    fam[k] := ff
            }
        }
    }
    body := fam.Has("Body") ? fam["Body"] : FontFamily()
    res := {Body: body, Semi: fam.Has("Semi") ? fam["Semi"] : 0, Cond: fam.Has("Cond") ? fam["Cond"] : 0
        , Mono: fam.Has("Mono") ? fam["Mono"] : 0, Coll: coll}
    return res
}

HitFont() => HitFonts().Body

; Schrift-Objekte je Größe nur einmal anlegen (spart Zeit in jedem Bild)
;  bold: 0 = normal, 1 = halbfett (SemiBold), 2 = fett.  face: "" | "cond" | "mono"
HitFontObj(size, bold, face := "") {
    static cache := Map()
    key := Round(size, 1) "|" bold "|" face
    if cache.Has(key)
        return cache[key]
    hf := HitFonts(), style := 0
    fam := face = "cond" ? hf.Cond : face = "mono" ? hf.Mono : bold = 1 ? hf.Semi : 0
    if !fam
        fam := hf.Body, style := bold ? 1 : 0
    font := 0
    if DllCall("gdiplus\GdipCreateFont", "Ptr", fam, "Float", size, "Int", style, "Int", 2, "Ptr*", &font) || !font {
        font := 0                                       ; Stil nicht vorhanden -> normal
        DllCall("gdiplus\GdipCreateFont", "Ptr", fam, "Float", size, "Int", 0, "Int", 2, "Ptr*", &font)
    }
    cache[key] := font
    return font
}

Brush(argb) {
    br := 0
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", argb, "Ptr*", &br)
    return br
}

PenOf(argb, w) {
    pen := 0
    DllCall("gdiplus\GdipCreatePen1", "UInt", argb, "Float", w, "Int", 2, "Ptr*", &pen)
    return pen
}

RectF(x, y, w, h) {
    b := Buffer(16)
    NumPut("Float", x, "Float", y, "Float", w, "Float", h, b)
    return b
}

FontFamily() {
    fam := 0
    if DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "Segoe UI", "Ptr", 0, "Ptr*", &fam)
        DllCall("gdiplus\GdipGetGenericFontFamilySansSerif", "Ptr*", &fam)
    return fam
}

RoundPath(x, y, w, h, r) {
    path := 0, d := r * 2
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &path)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x, "Float", y, "Float", d, "Float", d, "Float", 180, "Float", 90)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x + w - d, "Float", y, "Float", d, "Float", d, "Float", 270, "Float", 90)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x + w - d, "Float", y + h - d, "Float", d, "Float", d, "Float", 0, "Float", 90)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x, "Float", y + h - d, "Float", d, "Float", d, "Float", 90, "Float", 90)
    DllCall("gdiplus\GdipClosePathFigure", "Ptr", path)
    return path
}

; align: 0 = links, 1 = mittig, 2 = rechts; zu lang -> "…".  bold/face siehe HitFontObj
DrawText(g, text, x, y, w, h, size, bold, argb, align, face := "") {
    static fmts := Map()
    if !fmts.Has(align) {
        fmt := 0
        DllCall("gdiplus\GdipCreateStringFormat", "Int", 0x1000, "Int", 0, "Ptr*", &fmt)
        DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", fmt, "Int", align)
        DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", fmt, "Int", 1)
        DllCall("gdiplus\GdipSetStringFormatTrimming", "Ptr", fmt, "Int", 3)
        fmts[align] := fmt
    }
    if ((argb >> 24) & 0xFF) = 0
        return
    br := Brush(argb)
    DllCall("gdiplus\GdipDrawString", "Ptr", g, "WStr", String(text), "Int", -1, "Ptr", HitFontObj(size, bold, face), "Ptr", RectF(x, y, w, h), "Ptr", fmts[align], "Ptr", br)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
}

; ============================================================================
;  Walzen-Daten für die Treffer-Leiste
;  Chaos/Mageblood: {Lines: [Mod-Zeilen], Target: Nr. der Treffer-Zeile, Sub: Untertitel}
;  Divine:          {Values: [{Label, Digits, Unit}]}
; ============================================================================
ReelFromItem(item) {
    lines := [], target := 0, sub := "", legs := Map()
    for m in item.Mods {
        txt := Trim(m.Norm)
        if txt = ""
            continue
        lines.Push(txt)
        if m.Hit {
            if m.HasOwnProp("Legacy")
                legs[m.Legacy] := (legs.Has(m.Legacy) ? legs[m.Legacy] : 0) + 1
            if !target
                target := lines.Length, sub := (m.Tier ? "T" m.Tier "  " : "") ShortMod(txt)
        }
    }
    if legs.Count
        sub := MbHitSub(legs)
    return ReelMake(lines, target, sub)
}

; Mageblood-Untertitel, z.B. "Ruby ×2  ·  Sapphire"
MbHitSub(legs) {
    out := ""
    for n, c in legs
        out .= (out = "" ? "" : "  ·  ") n (c > 1 ? " ×" c : "")
    return out
}

ReelMake(lines, target, sub := "") {
    if lines.Length = 0
        return 0
    base := lines.Clone()
    while lines.Length < 4                                  ; kurze Items: Zeilen wiederholen, damit es nach Walze aussieht
        for x in base
            lines.Push(x)
    return {Lines: lines, Target: target >= 1 && target <= base.Length ? target : 1, Sub: sub}
}

; fehlende Walzen-Daten ersetzen (z.B. Treffer nur über eigene Text-Regeln)
HitReelReady(reel, style, hits) {
    if style = "dv"
        return IsObject(reel) && reel.HasOwnProp("Values") && reel.Values.Length ? reel : ReelDvTest()
    if IsObject(reel) && reel.HasOwnProp("Lines") && reel.Lines.Length
        return reel
    return ReelMake([StrReplace(T("hSub"), "{n}", Max(1, hits))], 1)
}

HitSubText(reel, style, hits) {
    if style = "dv" {
        n := reel.Values.Length
        return Dv.Any || n <= 1 ? T("hSubDvOne") : StrReplace(T("hSubDv"), "{n}", n)
    }
    if hits <= 1 && reel.HasOwnProp("Sub") && reel.Sub != ""
        return reel.Sub
    return StrReplace(T("hSub"), "{n}", hits)
}

; "172% increased Physical Damage" -> "increased Physical Damage"
ShortMod(s) {
    s := RegExReplace(s, "\(\s*-?[\d.]+\s*[-–]\s*-?[\d.]+\s*\)%?", "")
    s := RegExReplace(s, "[+\-]?\d+(?:\.\d+)?%?", "")
    s := RegExReplace(s, "^\s*(to|of)\s+", "")
    s := RegExReplace(s, "i)^Adds\s+to\s+", "Adds ")
    return Trim(RegExReplace(s, "\s{2,}", " "))
}

; Divine: erreichte Werte aller eingeschalteten Zahlen
ReelDv(vals) {
    out := []
    for L in Dv.Lines {
        if !DvLineHasRule(L.Key) || !vals.Has(L.Key)
            continue
        nums := vals[L.Key]
        for idx, r in Dv.Rules[L.Key] {
            if nums.Length < idx || nums[idx] = ""
                continue
            out.Push({Label: DvLabel(L.Text) (L.Nums.Length > 1 ? " · " idx : ""), Digits: NumStr(nums[idx]), Unit: DvUnit(L.Text, idx)
                , Need: (r.Op = "<=" ? "≤ " : "≥ ") NumStr(r.Val)})
        }
    }
    return out.Length ? {Values: out} : 0
}

; Test-Knopf: höchste Werte der eingestellten Zahlen, sonst ein Beispiel
ReelDvTest() {
    vals := Map()
    for L in Dv.Lines {
        nums := []
        for n in L.Nums
            nums.Push(n.Hi != "" ? n.Hi : n.V)
        vals[L.Key] := nums
    }
    r := ReelDv(vals)
    if IsObject(r)
        return r
    return {Values: [{Label: "Physical Damage", Digits: "87", Unit: "%", Need: "≥ 80"}, {Label: "Lightning Damage", Digits: "162", Unit: "", Need: "≥ 150"}
        , {Label: "Crit Damage Bonus", Digits: "24", Unit: "%", Need: "≥ 20"}]}
}

; Test-Knopf Chaos: zuletzt kopiertes Item, sonst ein Beispiel
ReelDemo() {
    if LastItemText != "" && IsObject(item := ParseItem(LastItemText)) && item.Mods.Length {
        lines := []
        for m in item.Mods
            if Trim(m.Norm) != ""
                lines.Push(Trim(m.Norm))
        tg := Min(lines.Length, 2)
        return ReelMake(lines, tg, lines.Length ? ShortMod(lines[tg]) : "")
    }
    return ReelMake(["15% increased Attack Speed", "Adds 14 to 20 Fire Damage", "172% increased Physical Damage"
        , "Adds 4 to 155 Lightning Damage", "+21 to Strength"], 3, "T1  increased Physical Damage")
}

; kurze Beschriftung einer Divine-Zahl: "169% increased Spell Damage" -> "Spell Damage"
DvLabel(text) {
    s := RegExReplace(text, "[+\-]?\d+(?:\.\d+)?%?", "")
    s := RegExReplace(s, "i)^\s*Adds\s+to\s+", "")
    s := RegExReplace(s, "i)^\s*(to|of)\s+", "")
    s := RegExReplace(s, "i)\bincreased\s+", "")
    s := RegExReplace(s, "i)^\s*Gain\s+of\s+", "")
    return Trim(RegExReplace(s, "\s{2,}", " "))
}

; steht hinter der idx-ten Zahl ein "%"?
DvUnit(text, idx) {
    pos := 1, i := 0
    while RegExMatch(text, "-?\d+(?:\.\d+)?", &rm, pos) {
        i++
        if i = idx
            return SubStr(text, rm.Pos + rm.Len, 1) = "%" ? "%" : ""
        pos := rm.Pos + rm.Len
    }
    return ""
}

; Zahl ohne Kommastellen-Rauschen: 176 -> "176", 9.03 -> "9.03"
NumStr(v) {
    if !IsNumber(v)
        return String(v)
    if Floor(v) = v
        return String(Integer(v))
    return RTrim(RTrim(Format("{:.2f}", v), "0"), ".")
}

; ============================================================================
;  Divine: Werte der vorhandenen Mods neu würfeln -> Schwelle je Zahl
;  Dv.Item  = Name des Items, für das die Regeln gelten
;  Dv.Lines = Mod-Zeilen: {Key, Base, Occ, Text, Nums: [{V, Lo, Hi}]}
;  Dv.Rules = Map(Key -> Map(Zahl-Index -> {Op, Val}));  Dv.Any: 0 = alle, 1 = eine reicht
; ============================================================================
; alle Zahlen einer Strg+C-Zeile; Strg+Alt+C liefert den Bereich gleich mit: "+49(40-55) to maximum Life"
DvNums(line) {
    out := [], pos := 1
    while pos := RegExMatch(line, "(-?\d+(?:\.\d+)?)(?:\((-?\d+(?:\.\d+)?)[-–](-?\d+(?:\.\d+)?)\))?", &rm, pos) {
        pos += StrLen(rm[0])
        lo := rm[2] != "" ? rm[2] + 0 : "", hi := rm[3] != "" ? rm[3] + 0 : ""
        if lo != "" && lo > hi
            tmp := lo, lo := hi, hi := tmp
        out.Push({V: rm[1] + 0, Lo: lo, Hi: hi})
    }
    return out
}

; Bereiche aus der Tier-Tabelle der Spieldaten (Rares/Magics, wenn Tier bekannt)
DvTierRanges(m) {
    out := []
    if !m.HasOwnProp("Gid") || !m.Tier || !DB.Groups.Has(m.Gid)
        return out
    for entry in StrSplit(DB.Groups[m.Gid].TierTxt, ";;") {
        f := StrSplit(entry, "~")
        if f.Length < 4 || f[1] != "T" m.Tier
            continue
        parts := StrSplit(f[4], " / ")
        part := parts.Length >= (m.HasOwnProp("GPart") ? m.GPart : 1) ? parts[m.HasOwnProp("GPart") ? m.GPart : 1] : parts[1]
        pos := 1
        while pos := RegExMatch(part, "\((-?\d+(?:\.\d+)?)-(-?\d+(?:\.\d+)?)\)|(-?\d+(?:\.\d+)?)", &rm, pos) {
            pos += StrLen(rm[0])
            if rm[1] != ""
                out.Push({Lo: Min(rm[1] + 0, rm[2] + 0), Hi: Max(rm[1] + 0, rm[2] + 0)})
            else
                out.Push({Lo: rm[3] + 0, Hi: rm[3] + 0})
        }
        break
    }
    return out
}

DvLinesFrom(item) {
    lines := [], seen := Map()
    for m in item.Mods {
        nums := DvNums(m.Text)
        if !nums.Length
            continue
        tr := DvTierRanges(m)
        for i, n in nums
            if n.Lo = "" && tr.Length >= i && tr[i].Lo != tr[i].Hi
                n.Lo := tr[i].Lo, n.Hi := tr[i].Hi
        base := LKey(m.Norm)
        if StrLen(base) < 4
            continue
        seen[base] := (seen.Has(base) ? seen[base] : 0) + 1
        lines.Push({Key: base (seen[base] > 1 ? "#" seen[base] : ""), BKey: base, Occ: seen[base], Text: m.Norm, Nums: nums, Mod: m})
    }
    return lines
}

DvRuleCount() {
    n := 0
    for key, rs in Dv.Rules
        n += rs.Count
    return n
}

DvActiveFor(item) => Dv.Item != "" && Dv.Item = item.Name && DvRuleCount() > 0
DvLineHasRule(key) => Dv.Rules.Has(key) && Dv.Rules[key].Count > 0

; vals: Map(Key -> [Zahlen]) -> erfüllt?
DvRulesOk(vals) {
    if DvRuleCount() = 0
        return false
    anyOk := false, allOk := true
    for key, rs in Dv.Rules {
        for idx, r in rs {
            v := vals.Has(key) && vals[key].Length >= idx ? vals[key][idx] : ""
            ok := v != "" && (r.Op = "<=" ? v <= r.Val : v >= r.Val)
            if ok
                anyOk := true
            else
                allOk := false
        }
    }
    return Dv.Any ? anyOk : allOk
}

DvLineOk(key, nums) {
    if !DvLineHasRule(key)
        return false
    for idx, r in Dv.Rules[key] {
        v := nums.Length >= idx ? nums[idx] : ""
        if v = "" || !(r.Op = "<=" ? v <= r.Val : v >= r.Val)
            return false
    }
    return true
}

; mit Fehleranzeige statt stillem Abbruch
DvFlowSafe(item, load) {
    global CurPage
    try {
        if load
            CurPage := "pDv"
        DvFlow(item)
        if load {
            n := 0
            for L in Dv.Lines
                n += L.Nums.Length
            if !St.Hit {
                ShowBanner(T("dvLoaded"), Dv.Item "   ·   " StrReplace(T("dvLoadedSub"), "{n}", n), Clr.Green)
                SetTimer(HideBanner, -2500)
            }
            WebPost(Map("type", "toast", "text", T("dvLoaded") " – " StrReplace(T("dvLoadedSub"), "{n}", n)))
        }
    } catch as e {
        LogError("Divine", e)
        msg := e.Message " (" e.What ", Zeile " e.Line ")"
        ShowBanner("Divine: " T("dvErr") " (v" APP_VER ")", msg, Clr.Red)
        SetTimer(HideBanner, -9000)
        WebPost(Map("type", "toast", "text", "Divine: " T("dvErr") " – " msg, "long", 1))
    }
}

DvFlow(item) {
    global MbMode
    MbMode := false
    cat := DetectCat(item)                       ; für Tier-Bereiche bei Rares
    if IsObject(cat)
        Evaluate(item, cat)
    for m in item.Mods
        m.Hit := false
    if CurPage = "pDv"
        DvLoad(item)
    lines := DvLinesFrom(item), vals := Map()
    for L in lines {
        nums := []
        for n in L.Nums
            nums.Push(n.V)
        vals[L.Key] := nums
        if DvLineOk(L.Key, nums)
            L.Mod.Hit := true
    }
    hits := DvRulesOk(vals) ? 1 : 0
    if Cfg.Mode = 3
        StartTrackDV(item, lines)
    WebPost(Map("type", "page", "id", "pDv"))
    if Cfg.ItemOverlay
        ShowItem(item, {Main: "Divine", Sub: Dv.Any ? T("dvOne") : T("dvAll")}, hits, 1)
    if St.On && !St.Hit {
        if DvRuleCount() > 0 && hits >= 1
            TriggerHit(hits, "dv", "", ReelDv(vals))
        else if St.Locked && Cfg.Mode >= 2
            Unlock()
    }
}

; Item in den Divine-Reiter laden (anderes Item -> Regeln neu, gleiches -> Regeln behalten)
DvLoad(item) {
    lines := DvLinesFrom(item)
    static prev := Map()                         ; Regeln früherer Items (falls man zurückwechselt)
    if item.Name != Dv.Item {
        if Dv.Item != "" && Dv.Rules.Count
            prev[Dv.Item] := Dv.Rules
        Dv.Rules := prev.Has(item.Name) ? prev[item.Name] : Map()
    } else {
        keep := Map()
        for L in lines
            keep[L.Key] := true
        drop := []
        for key in Dv.Rules
            if !keep.Has(key)
                drop.Push(key)
        for key in drop
            Dv.Rules.Delete(key)
    }
    Dv.Item := item.Name
    Dv.Lines := []
    for L in lines {
        ns := []
        for n in L.Nums
            ns.Push({V: n.V, Lo: n.Lo, Hi: n.Hi})
        Dv.Lines.Push({Key: L.Key, Text: L.Text, Nums: ns})
    }
    SaveDv(false)
    SendDv()
}

DvState() {
    lines := []
    for L in Dv.Lines {
        ns := []
        for n in L.Nums
            ns.Push(Map("v", n.V, "lo", n.Lo, "hi", n.Hi))
        lines.Push(Map("key", L.Key, "text", L.Text, "nums", ns))
    }
    rmap := Map()
    for key, rs in Dv.Rules {
        rm := Map()
        for idx, r in rs
            rm[idx] := Map("op", r.Op, "val", r.Val)
        rmap[key] := rm
    }
    return Map("item", Dv.Item, "any", Dv.Any, "lines", lines, "rules", rmap)
}

SendDv() => WebPost(Map("type", "dv", "dv", DvState()))

StartTrackDV(item, lines) {
    global Track, ClickX, ClickY
    names := []
    for n in item.NameLines
        if StrLen(LKey(n)) >= 4
            names.Push(LKey(n))
    truth := Map(), dl := []
    for L in lines {
        for i, n in L.Nums
            truth[L.Key "|" i] := n.V
        dl.Push({Key: L.Key, BKey: L.BKey, Occ: L.Occ, N: L.Nums.Length, Nums: L.Nums})
    }
    Track := {Active: names.Length > 0 && dl.Length > 0, Kind: "dv", Cat: "", Names: names, FracKeys: [], Expected: truth.Count
        , Truth: truth, LastSig: MbSig(truth), Thr: Cfg.OcrBest, Alts: OcrAlts([Cfg.OcrBest]), Rect: 0, DvLines: dl}
    if !Track.Active
        return
    MouseGetPos(&ClickX, &ClickY)
    SetTimer(Calibrate, -80)
}

; alle Zahlen einer gelesenen Zeile (typische Lesefehler O->0, l->1, S->5 ... korrigiert)
OcrNumbers(s) {
    out := [], pos := 1
    while pos := RegExMatch(s, "[+\-]?[0-9OolIS|B.]+%?", &rm, pos) {
        tok := rm[0]
        pos += StrLen(tok)
        if !RegExMatch(tok, "\d")
            continue
        if NumFixes.Has(tok) {
            out.Push(NumFixes[tok])
            continue
        }
        for a, b in Map("O", "0", "o", "0", "l", "1", "I", "1", "|", "1", "S", "5", "B", "8")
            tok := StrReplace(tok, a, b, true)
        if RegExMatch(tok, "-?\d+(?:\.\d+)?", &n)     ; Vorzeichen behalten (z.B. -10% to Fire Resistance)
            out.Push(n[0] + 0)
    }
    return out
}

; Eigenschafts-Zeile des Items ("Critical Hit Chance: 9.03%", "Requires: Level 62") - Mod-Zeilen haben nie ":"
IsPropLine(txt) => RegExMatch(txt, "[:;]\s*[+\-]?\d") > 0

; gleiche Zeile aus zwei Lesedurchgängen -> eine Gruppe (nach Höhe sortiert)
DvClusters(cands) {
    out := []
    for i in SortIdx(cands, (sg) => sg.Y) {
        sg := cands[i], placed := false
        for cl in out
            if Abs(cl[1].Y - sg.Y) < 0.6 * Max(cl[1].H, sg.H) {
                cl.Push(sg), placed := true
                break
            }
        if !placed
            out.Push([sg])
    }
    return out
}

AutoEvalDV(segs) {
    best := 0, head := 0
    for sg in segs {
        k := LKey(sg.Text)
        if StrLen(k) < 4
            continue
        for n in Track.Names {
            v := HeadSim(k, n)
            if v > best
                best := v, head := sg
        }
    }
    if best < 0.7
        return {Status: "nohead"}
    tip := []
    for sg in segs
        if Abs(sg.Cx - head.Cx) <= 2.0 * head.H && sg.Y >= head.Y - 3 * head.H
            tip.Push(sg)
    ; jede gelesene Zeile gehört nur zu dem Mod, dem sie am ähnlichsten ist (Eigenschaften mit ":" nie)
    owner := Map()
    for si, sg in tip {
        k := LKey(sg.Text)
        if StrLen(k) < 4 || IsPropLine(sg.Text)
            continue
        bs := 0, bk := ""
        for L in Track.DvLines {
            v := Sim(k, L.BKey)
            if v > bs
                bs := v, bk := L.BKey
        }
        if bs >= 0.82
            owner[si] := bk
    }
    vals := Map(), gv := Map(), unsure := false
    for L in Track.DvLines {
        cands := []
        for si, sg in tip
            if owner.Has(si) && owner[si] = L.BKey
                cands.Push(sg)
        clusters := DvClusters(cands)
        if clusters.Length < L.Occ {
            if DvLineHasRule(L.Key)
                unsure := true
            continue
        }
        cl := clusters[L.Occ], nums := 0, agree := true
        for sg in cl {
            ns := OcrNumbers(sg.Text)
            if ns.Length != L.N                      ; Zeile kaputt gelesen -> diese Lesung nicht verwenden
                continue
            if !IsObject(nums) {
                nums := ns
            } else {
                loop ns.Length
                    if ns[A_Index] != nums[A_Index]
                        agree := false
            }
        }
        if !IsObject(nums) || !agree {
            if DvLineHasRule(L.Key) || !agree
                unsure := true
            continue
        }
        for i, v in nums {
            n := L.Nums[i]
            if n.Lo != "" && (v < n.Lo || v > n.Hi)  ; außerhalb des möglichen Bereichs = sicher falsch gelesen
                unsure := true
            else if n.Lo = "" && n.V != 0 && (v < 0.6 * Abs(n.V) || v > 1.6 * Abs(n.V) + 1)
                unsure := true                       ; Bereich unbekannt: Divine halbiert/verdoppelt nie -> Ziffer verloren/zu viel
            if cl.Length < 2 && DvLineHasRule(L.Key) && Dv.Rules[L.Key].Has(i) {
                r := Dv.Rules[L.Key][i]                  ; knapp an der Schwelle -> zweiter Blick
                span := n.Lo != "" ? n.Hi - n.Lo : Abs(r.Val)
                if Abs(v - r.Val) <= Max(1, 0.15 * span)
                    unsure := true
            }
            gv[L.Key "|" i] := v
        }
        vals[L.Key] := nums
    }
    hits := DvRulesOk(vals) ? 1 : 0
    return {Status: "ok", Hits: hits, Unsure: unsure, Sig: MbSig(gv), Groups: gv.Count, GidVals: gv, Head: head, TipSegs: tip, Vals: vals}
}

LoadDv() {
    Dv.Item := IniRead(INI, "Divine", "Item", "")
    Dv.Any := IniRead(INI, "Divine", "Modus", "0") = "1" ? 1 : 0
    for part in StrSplit(IniRead(INI, "Divine", "Regeln", ""), ";;") {
        f := StrSplit(part, "|")
        if f.Length = 4 && IsInteger(f[2]) && IsNumber(f[4]) {
            if !Dv.Rules.Has(f[1])
                Dv.Rules[f[1]] := Map()
            Dv.Rules[f[1]][Integer(f[2])] := {Op: f[3] = "<=" ? "<=" : ">=", Val: f[4] + 0}
        }
    }
    loop 40 {
        v := IniRead(INI, "DivineZeilen", A_Index, "")
        if v = ""
            break
        f := StrSplit(v, "¦")
        if f.Length < 3
            continue
        ns := []
        for t3 in StrSplit(f[3], ",") {
            q := StrSplit(t3, ":")
            if q.Length = 3 && IsNumber(q[1])
                ns.Push({V: q[1] + 0, Lo: IsNumber(q[2]) ? q[2] + 0 : "", Hi: IsNumber(q[3]) ? q[3] + 0 : ""})
        }
        Dv.Lines.Push({Key: f[1], Text: f[2], Nums: ns})
    }
}

SaveDv(flash := true) {
    r := ""
    for key, rs in Dv.Rules
        for idx, x in rs
            r .= (r = "" ? "" : ";;") key "|" idx "|" x.Op "|" x.Val
    try {
        IniWrite(Dv.Item, INI, "Divine", "Item")
        IniWrite(Dv.Any, INI, "Divine", "Modus")
        IniWrite(r, INI, "Divine", "Regeln")
        try IniDelete(INI, "DivineZeilen")
        for i, L in Dv.Lines {
            ns := ""
            for n in L.Nums
                ns .= (ns = "" ? "" : ",") n.V ":" n.Lo ":" n.Hi
            IniWrite(L.Key "¦" L.Text "¦" ns, INI, "DivineZeilen", i)
        }
    }
    if flash
        FlashSaved()
}

; ============================================================================
;  Mageblood: 4 Mage's-Legacy-Plätze (Doppelte zählen!) + Effekt pro Duplikat
; ============================================================================
IsMageblood(item) {
    for n in item.NameLines
        if InStr(n, "Mageblood")
            return true
    return false
}

HasVal(arr, v) {
    for x in arr
        if x = v
            return true
    return false
}

MbRuleCount() => Mb.Rules.Count + (Mb.Any > 0 ? 1 : 0) + (Mb.Eff != "" ? 1 : 0) + (Mb.Dup ? 1 : 0)

MbBanList() {
    a := []
    for n in LEGACIES
        if Mb.Ban.Has(n)
            a.Push(n)
    return a
}

MbBanText() {
    out := ""
    for n in MbBanList()
        out .= (out = "" ? "" : ", ") n
    return out
}

; Treffer-Regel:
;  - ein "nicht gewolltes" Legacy drauf  -> nie ein Treffer
;  - Effekt-Minimum (falls gesetzt) muss immer erfüllt sein
;  - dann: ALLE Wunsch-Regeln erfüllt  ODER  (Option an) irgendein Legacy doppelt
MbRulesOk(counts, eff) {
    if MbRuleCount() = 0
        return false
    for name, n in counts
        if n > 0 && Mb.Ban.Has(name)
            return false
    if Mb.Eff != "" && (eff = "" || eff < Mb.Eff)
        return false
    mx := 0
    for name, n in counts
        mx := Max(mx, n)
    conds := Mb.Rules.Count + (Mb.Any > 0 ? 1 : 0)
    if Mb.Dup && mx >= 2
        return true
    if conds = 0
        return !Mb.Dup                      ; nur Effekt eingestellt
    for name, n in Mb.Rules
        if (counts.Has(name) ? counts[name] : 0) < n
            return false
    if Mb.Any > 0 && mx < Mb.Any
        return false
    return true
}

EvaluateMB(item) {
    counts := Map(), eff := ""
    for m in item.Mods {
        if RegExMatch(m.Norm, "i)^Legacy of (\w+)", &mm) {
            name := LegacyName(mm[1])
            if name != "" {
                counts[name] := (counts.Has(name) ? counts[name] : 0) + 1
                m.Kind := "L", m.Legacy := name
            }
        } else if InStr(m.Norm, "per duplicate") {
            eff := FirstNumber(m.Norm)
        }
    }
    ok := MbRulesOk(counts, eff)
    if ok
        for m in item.Mods
            if m.HasOwnProp("Legacy") && (Mb.Rules.Has(m.Legacy) || ((Mb.Any > 0 || Mb.Dup) && counts[m.Legacy] >= 2))
                m.Hit := true
    return ok ? 1 : 0
}

LegacyName(s) {
    for n in LEGACIES
        if n = s
            return n
    return ""
}

StartTrackMB(item) {
    global Track, ClickX, ClickY
    names := []
    for n in item.NameLines
        if StrLen(LKey(n)) >= 4
            names.Push(LKey(n))
    counts := Map(), eff := ""
    for m in item.Mods {
        if RegExMatch(m.Norm, "i)^Legacy of (\w+)", &mm) && LegacyName(mm[1]) != ""
            counts[LegacyName(mm[1])] := (counts.Has(LegacyName(mm[1])) ? counts[LegacyName(mm[1])] : 0) + 1
        else if InStr(m.Norm, "per duplicate")
            eff := FirstNumber(m.Norm)
    }
    truth := Map()
    for name, n in counts
        truth["L:" name] := n
    if eff != ""
        truth["EFF"] := eff
    Track := {Active: names.Length > 0, Kind: "mb", Cat: "", Names: names, FracKeys: [], Expected: truth.Count
        , Truth: truth, LastSig: MbSig(truth), Thr: Cfg.OcrBest, Alts: OcrAlts([Cfg.OcrBest]), Rect: 0}
    if !Track.Active
        return
    MouseGetPos(&ClickX, &ClickY)
    SetTimer(Calibrate, -80)
}

MbSig(vals) {
    s := ""
    for k, v in vals
        s .= k ":" v "`n"
    return SortSig(s)
}

AutoEvalMB(segs) {
    static effKey := LKey("All Mage's Legacies have % increased effect per duplicate Mage's Legacy you have")
    best := 0, head := 0
    for sg in segs {
        k := LKey(sg.Text)
        if StrLen(k) < 4
            continue
        for n in Track.Names {
            v := HeadSim(k, n)
            if v > best
                best := v, head := sg
        }
    }
    if best < 0.7
        return {Status: "nohead"}
    counts := Map(), eff := "", legLines := 0, unsure := false, tip := [], legOrder := []
    for sg in segs {
        if Abs(sg.Cx - head.Cx) > 2.0 * head.H || sg.Y < head.Y - 3 * head.H
            continue
        tip.Push(sg)
        k := LKey(sg.Text)
        if StrLen(k) < 8
            continue
        ; Legacy-Zeile?
        bn := "", bv := 0
        for n in LEGACIES {
            v := Sim(k, "legacyof" StrLower(n))
            if v > bv
                bv := v, bn := n
        }
        if bv >= 0.85 {
            counts[bn] := (counts.Has(bn) ? counts[bn] : 0) + 1, legLines++
            legOrder.Push(bn)
            continue
        }
        if bv >= 0.65 && InStr(k, "lega") {
            unsure := true
            continue
        }
        ; Effekt-Zeile (kann umgebrochen sein -> Teil reicht)
        if InStr(k, "increasedeffect") || InStr(k, "perduplicate") || Sim(k, effKey) >= 0.7 {
            nv := OcrNumber(sg.Text)
            if nv != ""
                eff := nv
        }
    }
    if legLines < 4                                ; Mageblood hat immer 4 Legacies
        unsure := true
    if Track.Truth.Has("EFF") && eff = ""
        unsure := true
    vals := Map()
    for name, n in counts
        vals["L:" name] := n
    if eff != ""
        vals["EFF"] := eff
    hits := MbRulesOk(counts, eff) ? 1 : 0
    reelL := [], reelT := 0, legs := Map()
    for n in legOrder {
        reelL.Push("Legacy of " n)
        if Mb.Rules.Has(n) || ((Mb.Any > 0 || Mb.Dup) && counts[n] >= 2) {
            legs[n] := counts[n]
            if !reelT
                reelT := reelL.Length
        }
    }
    return {Status: "ok", Hits: hits, Unsure: unsure, Sig: MbSig(vals), Groups: vals.Count
        , GidVals: vals, Head: head, TipSegs: tip, Reel: ReelMake(reelL, reelT, legs.Count ? MbHitSub(legs) : "")}
}

LoadMb() {
    v := IniRead(INI, "Mageblood", "Regeln", "")
    for part in StrSplit(v, ",") {
        kv := StrSplit(part, ":")
        if kv.Length = 2 && LegacyName(kv[1]) != "" && IsInteger(kv[2])
            Mb.Rules[LegacyName(kv[1])] := Max(1, Min(4, Integer(kv[2])))
    }
    a := IniRead(INI, "Mageblood", "Beliebig", "0")
    Mb.Any := IsInteger(a) ? Integer(a) : 0
    e := IniRead(INI, "Mageblood", "Effekt", "")
    Mb.Eff := IsNumber(e) ? e + 0 : ""
    for n in StrSplit(IniRead(INI, "Mageblood", "Verboten", ""), ",")
        if LegacyName(Trim(n)) != "" && !Mb.Rules.Has(LegacyName(Trim(n)))
            Mb.Ban[LegacyName(Trim(n))] := true
    Mb.Dup := IniRead(INI, "Mageblood", "JedesDuplikat", "0") = "1" ? 1 : 0
}

SaveMb() {
    r := ""
    for name, n in Mb.Rules
        r .= (r = "" ? "" : ",") name ":" n
    try {
        IniWrite(r, INI, "Mageblood", "Regeln")
        IniWrite(Mb.Any, INI, "Mageblood", "Beliebig")
        IniWrite(Mb.Eff, INI, "Mageblood", "Effekt")
        IniWrite(MbBanText(), INI, "Mageblood", "Verboten")
        IniWrite(Mb.Dup, INI, "Mageblood", "JedesDuplikat")
    }
    RefreshTarget()
    FlashSaved()
}
