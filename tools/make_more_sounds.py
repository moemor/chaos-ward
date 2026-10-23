"""Weitere Treffer-Sounds (selbst erzeugt, keine fremden Samples):
gong.wav     tiefer Gong mit langem Ausklang
crystal.wav  helle Kristall-Kaskade
harp.wav     kurzes Harfen-Arpeggio (gezupft)
drum.wav     zwei tiefe Trommelschläge
Aufruf: python3 make_more_sounds.py <ordner>"""
import sys
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 44100
rng = np.random.default_rng(23)


def lowpass(x, f):
    b, a = butter(2, f / (SR / 2))
    return lfilter(b, a, x)


def bandpass(x, lo, hi):
    b, a = butter(2, [lo / (SR / 2), hi / (SR / 2)], btype='band')
    return lfilter(b, a, x)


def at(buf, t0, sig, g=1.0):
    i = int(t0 * SR)
    n = min(len(sig), len(buf) - i)
    if n > 0:
        buf[i:i + n] += sig[:n] * g


def room(x, mix=.25):
    y = np.copy(x)
    for dl, g in ((0.031, .5), (0.047, .4), (0.071, .32), (0.103, .24), (0.157, .17), (0.211, .12)):
        n = int(SR * dl)
        z = np.zeros_like(x)
        z[n:] = x[:-n] * g
        y += lowpass(z, 4000) * mix
    return y


def write(path, x):
    x = x / np.max(np.abs(x)) * 0.89
    k = int(SR * .2)
    x[-k:] *= np.linspace(1, 0, k)
    wavfile.write(path, SR, (np.stack([x, x], 1) * 32767).astype(np.int16))
    print('ok', path, f'{len(x) / SR:.2f} s')


def gong():
    t = np.arange(int(SR * 3.2)) / SR
    f0 = 98.0
    parts = ((1, 1, 2.6), (1.48, .55, 1.8), (2.03, .45, 1.4), (2.74, .3, 1.0), (3.6, .22, .7), (4.9, .12, .5))
    x = sum(w * np.sin(2 * np.pi * f0 * k * t * (1 + 0.004 * np.exp(-t * 3))) * np.exp(-t / d) for k, w, d in parts)
    x *= np.clip(t / 0.012, 0, 1)
    hit = bandpass(rng.standard_normal(len(t)), 200, 3000) * np.exp(-t / 0.02) * 0.6
    return room(x + hit, .3)


def crystal():
    L = 2.2
    buf = np.zeros(int(SR * L))
    notes = [1760.0, 2217.5, 2637.0, 3520.0, 2960.0, 4186.0]
    for i, f in enumerate(notes):
        t = np.arange(int(SR * 1.4)) / SR
        tone = sum(w * np.sin(2 * np.pi * f * k * t) * np.exp(-t / (0.5 / k)) for k, w in ((1, 1), (2.76, .3), (5.4, .12)))
        at(buf, 0.02 + i * 0.07, tone, 0.5 - i * 0.04)
    return room(buf, .35)


def harp():
    L = 2.0
    buf = np.zeros(int(SR * L))
    for i, f in enumerate([392.0, 493.9, 587.3, 784.0, 987.8]):   # G-Dur aufwärts
        n = int(SR * 1.5)
        period = int(SR / f)
        y = np.zeros(n)                                  # Karplus-Strong: gezupfte Saite
        y[:period] = rng.uniform(-1, 1, period)
        for j in range(period, n):
            y[j] = 0.996 * 0.5 * (y[j - period] + y[j - period + 1])
        at(buf, i * 0.075, lowpass(y, 5000), 0.55)
    return room(buf, .3)


def drum():
    L = 1.6
    buf = np.zeros(int(SR * L))
    for t0, g in ((0.0, 0.8), (0.18, 1.0)):
        t = np.arange(int(SR * 0.9)) / SR
        body = np.sin(2 * np.pi * (62 + 60 * np.exp(-t / 0.03)) * t) * np.exp(-t / 0.22)
        skin = bandpass(rng.standard_normal(len(t)), 120, 1500) * np.exp(-t / 0.025) * 0.5
        at(buf, t0, body + skin, g)
    return room(buf, .22)


if __name__ == '__main__':
    out = sys.argv[1]
    for name, fn in (('gong', gong), ('crystal', crystal), ('harp', harp), ('drum', drum)):
        write(f'{out}/{name}.wav', fn())
