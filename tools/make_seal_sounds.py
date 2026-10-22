"""Sound "Siegel" (selbst erzeugt, keine fremden Samples), genau auf die Treffer-Leiste geschnitten:
 0,04-0,46 s  24 leise Kerben-Ticks (wie die Kerben im Bild aufleuchten)
 0,42-0,50 s  das Schloss dreht sich (kurzes Reiben)
 0,50/0,556 s Riegel klickt, Schloss rastet ein (tiefer Schlag)
 ab 0,56 s    ein warmer, kurzer Ton (Divine: heller, mit leisem Schimmer)
seal_chaos.wav / seal_dv.wav       = mit Anlauf (Animation "Siegel")
seal_chaos_now.wav / seal_dv_now.wav = nur Einrasten + Ton (Animation "Sofort")
Aufruf: python3 make_seal_sounds.py <ordner>"""
import sys
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 44100
LOCK = 0.556
rng = np.random.default_rng(11)


def bandpass(x, lo, hi):
    b, a = butter(2, [lo / (SR / 2), hi / (SR / 2)], btype='band')
    return lfilter(b, a, x)


def lowpass(x, f):
    b, a = butter(2, f / (SR / 2))
    return lfilter(b, a, x)


def at(buf, t0, sig, gain=1.0):
    i = int(round(t0 * SR))
    if i < 0:
        sig, i = sig[-i:], 0
    n = min(len(sig), len(buf) - i)
    if n > 0:
        buf[i:i + n] += sig[:n] * gain


def tick(f, dur=0.007):
    t = np.arange(int(SR * dur)) / SR
    n = bandpass(rng.standard_normal(len(t)), 2500, 7000) * np.exp(-t / 0.0012)
    return 0.5 * n + 0.6 * np.sin(2 * np.pi * f * t) * np.exp(-t / 0.0018)


def click(f=1900, dur=0.03):
    t = np.arange(int(SR * dur)) / SR
    n = bandpass(rng.standard_normal(len(t)), 900, 5000) * np.exp(-t / 0.003)
    return 0.7 * n + 0.5 * np.sin(2 * np.pi * f * t) * np.exp(-t / 0.005)


def thud():
    t = np.arange(int(SR * 0.4)) / SR
    body = np.sin(2 * np.pi * 105 * t + 2.5 * np.exp(-t / 0.015)) * np.exp(-t / 0.075)
    knock = bandpass(rng.standard_normal(len(t)), 250, 1800) * np.exp(-t / 0.01)
    return 0.95 * body + 0.6 * knock


def turn():
    t = np.arange(int(SR * 0.09)) / SR
    env = np.sin(np.pi * t / t[-1]) ** 2
    return bandpass(rng.standard_normal(len(t)), 900, 2600) * env


def tone(freqs, dur, decay, bright):
    t = np.arange(int(SR * dur)) / SR
    out = np.zeros_like(t)
    for f, w in freqs:
        for k, kw in ((1, 1.0), (2, 0.28 * bright), (3, 0.10 * bright), (4.2, 0.05 * bright)):
            out += w * kw * np.sin(2 * np.pi * f * k * t) * np.exp(-t / (decay / k ** 0.6))
    att = np.clip(t / 0.006, 0, 1)
    return lowpass(out * att, 7000 if bright > 1 else 4500)


def room(x, mix=.22):
    y = np.copy(x)
    for dl, g in ((0.023, .45), (0.037, .38), (0.059, .3), (0.083, .22), (0.121, .15)):
        n = int(SR * dl)
        z = np.zeros_like(x)
        z[n:] = x[:-n] * g
        y += lowpass(z, 3500) * mix
    return y


def write(name, x):
    x = x / np.max(np.abs(x)) * 0.89
    k = int(SR * .15)
    x[-k:] *= np.linspace(1, 0, k)
    wavfile.write(name, SR, (np.stack([x, x], 1) * 32767).astype(np.int16))
    print('ok', name, f'{len(x) / SR:.2f} s')


def seal(dv, now):
    L = 2.2
    buf = np.zeros(int(SR * L))
    sh = -0.48 if now else 0.0                       # "Sofort": ohne Anlauf
    if not now:
        for i in range(24):                          # Kerben: gleiche Kurve wie im Bild
            ti = 0.04 + 0.42 * (1 - (1 - i / 24) ** (1 / 3))
            big = i % 6 == 0
            at(buf, ti, tick(3100 if big else 3900 + 300 * rng.random()), (0.16 if big else 0.10) + 0.06 * i / 24)
        at(buf, 0.42, turn(), 0.10)
    at(buf, 0.500 + sh, click(), 0.42)
    at(buf, LOCK + sh, thud(), 0.95)
    if dv:
        at(buf, LOCK + 0.012 + sh, tone([(659.3, 1.0), (987.8, 0.55), (1318.5, 0.25)], 1.7, 0.75, 1.6), 0.42)
        for i in range(9):                           # leiser Schimmer
            tt = np.arange(int(SR * 0.3)) / SR
            f = 3200 + rng.random() * 2600
            at(buf, LOCK + 0.08 + i * 0.07 + 0.03 * rng.random() + sh, np.sin(2 * np.pi * f * tt) * np.exp(-tt / 0.06), 0.035)
    else:
        at(buf, LOCK + 0.012 + sh, tone([(392.0, 1.0), (587.3, 0.5), (196.0, 0.35)], 1.5, 0.6, 1.0), 0.46)
    return room(buf, 0.26 if dv else 0.2)


if __name__ == '__main__':
    out = sys.argv[1]
    for dv in (False, True):
        for now in (False, True):
            write(f"{out}/seal_{'dv' if dv else 'chaos'}{'_now' if now else ''}.wav", seal(dv, now))
