"""Sound "Spielautomat" (selbst erzeugt, keine fremden Samples), passend zur Walzen-Animation der Treffer-Leiste:
slot_chaos.wav  = Walze rattert und wird langsamer (Klick je Zeile), Klack beim Einrasten bei 0,90 s, dann Gewinn-Glocken + Münzregen
slot_dv.wav     = Ziffern ticken, drei helle Einrast-Klicks, bei 1,05 s ein strahlender Akkord mit Schimmer
Aufruf: python3 make_slot_sounds.py <ordner>"""
import sys
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 44100
rng = np.random.default_rng(7)


def bell(t, f, d, parts=((1, 1), (2.76, .45), (5.4, .25), (8.93, .12))):
    return sum(w * np.sin(2 * np.pi * f * k * t) * np.exp(-t / (d / k ** .5)) for k, w in parts)


def at(buf, t0, sig, gain=1.0):
    i = int(t0 * SR)
    n = min(len(sig), len(buf) - i)
    if n > 0:
        buf[i:i + n] += sig[:n] * gain


def bandpass(x, lo, hi):
    b, a = butter(2, [lo / (SR / 2), hi / (SR / 2)], btype='band')
    return lfilter(b, a, x)


def lowpass(x, f):
    b, a = butter(2, f / (SR / 2))
    return lfilter(b, a, x)


def click(f=2400, dur=0.012, bright=1.0):
    t = np.arange(int(SR * dur)) / SR
    n = bandpass(rng.standard_normal(len(t)), 900, 6000) * np.exp(-t / 0.0025)
    tone = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.004)
    return 0.6 * n * bright + 0.5 * tone


def clunk():
    t = np.arange(int(SR * 0.35)) / SR
    body = np.sin(2 * np.pi * 92 * t + 3 * np.exp(-t / 0.02)) * np.exp(-t / 0.07)
    knock = bandpass(rng.standard_normal(len(t)), 300, 2500) * np.exp(-t / 0.012)
    return 0.9 * body + 0.7 * knock


def reverb(x, mix=.3):
    y = np.copy(x)
    for dl, g in ((0.029, .5), (0.043, .42), (0.067, .33), (0.101, .25), (0.149, .18)):
        n = int(SR * dl)
        z = np.zeros_like(x)
        z[n:] = x[:-n] * g
        y += z * mix
    return y


def write(name, x):
    x = x / np.max(np.abs(x)) * 0.89
    fade = np.ones_like(x)
    k = int(SR * .12)
    fade[-k:] = np.linspace(1, 0, k)
    x = x * fade
    wavfile.write(name, SR, (np.stack([x, x], 1) * 32767).astype(np.int16))
    print('ok', name, f'{len(x) / SR:.2f} s')


def chaos(out):
    land, total, L = 0.90, 32, 3.0
    buf = np.zeros(int(SR * L))
    # Walze: Klick je vorbeilaufender Zeile, Kurve wie im Bild (ease-out kubisch)
    for k in range(1, total + 1):
        tk = land * (1 - (1 - k / total) ** (1 / 3))
        if tk >= land - 0.005:
            continue
        at(buf, tk, click(2300 + 300 * rng.random(), bright=0.8), 0.55 + 0.35 * (k / total))
    # mechanisches Surren, wird mit der Walze leiser und tiefer
    t = np.arange(int(SR * land)) / SR
    hum = bandpass(rng.standard_normal(len(t)), 180, 1400) * (1 - t / land) ** 1.5 * 0.10
    at(buf, 0, hum)
    at(buf, land, clunk(), 0.9)
    # Gewinn: Glocken-Arpeggio C6 E6 G6 C7 + Akkord
    notes = [1046.5, 1318.5, 1568.0, 2093.0]
    for i, f in enumerate(notes):
        tt = np.arange(int(SR * 1.6)) / SR
        at(buf, land + 0.03 + i * 0.075, bell(tt, f, 0.9), 0.42)
    tt = np.arange(int(SR * 1.9)) / SR
    chord = sum(bell(tt, f, 1.3) for f in (1046.5, 1318.5, 1568.0)) / 3
    at(buf, land + 0.36, chord, 0.55)
    # Münzregen
    for i in range(22):
        t0 = land + 0.12 + rng.random() * 0.9
        tt = np.arange(int(SR * 0.4)) / SR
        f = 2600 + rng.random() * 1800
        coin = bell(tt, f, 0.12, ((1, 1), (2.4, .5), (4.1, .3)))
        at(buf, t0, coin, 0.10 + 0.08 * rng.random())
    write(out + '/slot_chaos.wav', reverb(buf, .28))


def divine(out):
    land, L = 1.05, 3.4
    buf = np.zeros(int(SR * L))
    # Ziffern ticken (leiser, heller), Dichte nimmt ab
    tk = 0.03
    while tk < land - 0.04:
        at(buf, tk, click(3400 + 600 * rng.random(), 0.008, 0.5), 0.24)
        tk += 0.028 + 0.05 * (tk / land) ** 2
    # drei Einrast-Klicks (Zeilen fertig)
    for t0 in (0.55, 0.80, land - 0.08):
        at(buf, t0, click(1800, 0.02, 1.0), 0.45)
    # strahlender Akkord: Glocken + weicher Chor-Teppich
    tt = np.arange(int(SR * 2.3)) / SR
    for i, f in enumerate((1318.5, 1661.2, 1975.5, 2637.0)):
        at(buf, land + i * 0.05, bell(tt, f, 1.4), 0.36)
    pad_t = np.arange(int(SR * 2.3)) / SR
    env = np.clip(pad_t / 0.25, 0, 1) * np.exp(-np.maximum(pad_t - 0.5, 0) / 0.9)
    pad = sum(np.sin(2 * np.pi * f * pad_t * (1 + d)) for f in (659.3, 830.6, 987.8) for d in (-0.003, 0, 0.003))
    at(buf, land - 0.02, lowpass(pad, 3000) * env / 9, 0.55)
    # Schimmer: hohe, kurze Funken
    for i in range(26):
        t0 = land + 0.05 + rng.random() * 1.3
        tt = np.arange(int(SR * 0.25)) / SR
        at(buf, t0, np.sin(2 * np.pi * (4200 + rng.random() * 2500) * tt) * np.exp(-tt / 0.05), 0.05)
    write(out + '/slot_dv.wav', reverb(buf, .38))


if __name__ == '__main__':
    chaos(sys.argv[1])
    divine(sys.argv[1])
