"""Weitere Treffer-Sounds (selbst erzeugt, keine fremden Samples):
chime = helle Glocke mit Hall, ping = kurz & leise, coin = Münz-Klimpern (Doppelton)."""
import sys, numpy as np
from scipy.io import wavfile
SR = 44100
def env(t, a, d): return np.clip(t / a, 0, 1) * np.exp(-np.maximum(t - a, 0) / d)
def bell(t, f, d, parts=((1, 1), (2.76, .45), (5.4, .25), (8.93, .12))):
    return sum(w * np.sin(2 * np.pi * f * k * t) * np.exp(-t / (d / k ** .5)) for k, w in parts)
def reverb(x, mix=.3):
    y = np.copy(x)
    for dl, g in ((0.031, .5), (0.047, .4), (0.071, .3), (0.113, .22)):
        n = int(SR * dl); z = np.zeros_like(x); z[n:] = x[:-n] * g; y += z * mix
    return y
def write(name, x):
    x = x / np.max(np.abs(x)) * 0.89
    fade = np.ones_like(x); k = int(SR * .08); fade[-k:] = np.linspace(1, 0, k)
    wavfile.write(name, SR, (np.stack([x * fade, x * fade], 1) * 32767).astype(np.int16)); print('ok', name)
out = sys.argv[1]
t = np.arange(int(SR * 2.4)) / SR
x = bell(t, 880, 1.2) * env(t, .004, 9) + .7 * bell(np.maximum(t - .12, 0), 1318.5, 1.0) * (t > .12) + .5 * bell(np.maximum(t - .24, 0), 1760, .9) * (t > .24)
write(out + '/chime.wav', reverb(x, .35))
t = np.arange(int(SR * .7)) / SR
write(out + '/ping.wav', reverb(np.sin(2 * np.pi * 1567.98 * t) * env(t, .003, .12) + .3 * np.sin(2 * np.pi * 3135.96 * t) * env(t, .003, .06), .15) * .6)
t = np.arange(int(SR * 1.2)) / SR
c = lambda t0, f: bell(np.maximum(t - t0, 0), f, .35, ((1, 1), (2.4, .5), (4.1, .3), (6.3, .2))) * (t > t0)
write(out + '/coin.wav', reverb(c(0, 1975.5) + .9 * c(.09, 2637), .2))
