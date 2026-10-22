"""Erzeugt weiche Lichtstrahlen-Texturen für die Treffer-Leiste (weiß, Alpha trägt die Form).
rays_wide.png: wenige breite, weiche Strahlen | rays_fine.png: viele feine Strahlen. Selbst erzeugt."""
import sys, numpy as np
from PIL import Image
from scipy import ndimage
N = 512
out = sys.argv[1]
y, x = np.mgrid[0:N, 0:N].astype(float)
c = (N - 1) / 2
dx, dy = (x - c) / c, (y - c) / c
r = np.sqrt(dx * dx + dy * dy)
ang = np.arctan2(dy, dx)
rng = np.random.default_rng(11)

def rays(count, wmin, wmax, imin, imax, seed_shift, streak):
    a = np.zeros((N, N))
    base = np.linspace(0, 2 * np.pi, count, endpoint=False) + rng.uniform(0, 2 * np.pi / count, count) * 0.7
    for th in base:
        w = np.radians(rng.uniform(wmin, wmax))
        inten = rng.uniform(imin, imax)
        d = np.angle(np.exp(1j * (ang - th)))                  # Winkelabstand -pi..pi
        prof = np.exp(-(d / w) ** 2)                            # weiche Kante (Gauß)
        # Strahl wird nach außen breiter wirkend dunkler, mit leichten Längsstreifen
        length = rng.uniform(0.75, 1.0)
        fall = np.clip(1 - r / length, 0, 1) ** 1.7
        st = 1 + streak * np.sin(r * rng.uniform(18, 34) + rng.uniform(0, 6.28))
        a = np.maximum(a, prof * inten * fall * st)
    # nicht im Zentrum beginnen (dort liegt die Leiste), weicher Einstieg
    a *= np.clip((r - 0.05) / 0.18, 0, 1) ** 1.2
    return np.clip(a, 0, 1)

wide = ndimage.gaussian_filter(rays(22, 1.6, 5.5, 0.35, 1.0, 0, 0.10), 1.2)
fine = ndimage.gaussian_filter(rays(64, 0.35, 1.1, 0.25, 0.9, 1, 0.18), 0.7)
for name, a in [('rays_wide.png', wide), ('rays_fine.png', fine)]:
    a = a / max(a.max(), 1e-6)
    img = np.dstack([np.full((N, N), 255), np.full((N, N), 255), np.full((N, N), 255), (a * 255)]).astype('uint8')
    Image.fromarray(img, 'RGBA').save(f'{out}/{name}', optimize=True)
    print(name, 'max', round(a.max(), 2))
