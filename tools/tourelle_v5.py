"""Tourelle V5 : compose les 5 directions à partir des poses de la planche Gemini (docs/raw/V5/planches/tourelle_poses,
sorties de tools/decoupe_planche.py), qui dessinait un pied (trépied, sacs de sable) différent à chaque pose.

    python3 tools/tourelle_v5.py

Pied commun = celui de la pose « right » (cercle de sacs complet), tête (boîtier, canon, bande de balles) de chaque pose
posée dessus par le coin avant du bas du boîtier (POINTS). Écrit docs/raw/V5/base_turret_<direction>.png, même toile
et même pied pour toutes : seule la tête change quand la tourelle tourne. Puis tools/process_assets.py --source docs/raw/V5."""
import os

import numpy as np
from PIL import Image
from scipy import ndimage

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
POSES = os.path.join(RACINE, "docs", "raw", "V5", "planches", "tourelle_poses")
SORTIE = os.path.join(RACINE, "docs", "raw", "V5")
# Coin avant du bas du boîtier (bas du boîtier au milieu pour « up », vu de dos), pixels des poses découpées
POINTS = {"down": (300, 290), "down_right": (280, 295), "right": (262, 295), "up_right": (210, 335), "up": (277, 375)}
PIED = "right"
SOUS_TETE = 55      # sous le point : bande où il n'y a que des pieds du trépied (et les bouts de la bande de balles)
MARGE = 200


def lire(direction):
    p = np.asarray(Image.open(os.path.join(POSES, "base_turret_%s.png" % direction)).convert("RGB")).astype(int)
    r, g, b = p[..., 0], p[..., 1], p[..., 2]
    sujet = ~((r - g > 100) & (b - g > 100))
    return p, sujet


def pieds_trepied(p):
    """Métal lavande des pieds du trépied, avec leur contour noir."""
    r, g, b = p[..., 0], p[..., 1], p[..., 2]
    metal = (b - r > 14) & (p.max(-1) > 70)
    return ndimage.binary_dilation(metal, iterations=9)


def main():
    p, sujet = lire(PIED)
    px, py = POINTS[PIED]
    ys = np.arange(p.shape[0])[:, None]
    # Pied : tout sous le boîtier, sauf ce qui n'est pas un pied du trépied juste dessous (bande de balles)
    pied = sujet & (ys > py + 2)
    pied &= ~((ys <= py + SOUS_TETE) & ~pieds_trepied(p))
    fond = p[5, 5]
    h, w = p.shape[:2]
    for direction, (tx, ty) in POINTS.items():
        toile = np.zeros((h + 2 * MARGE, w + 2 * MARGE, 3), np.int64)
        toile[:] = fond
        toile[MARGE:MARGE + h, MARGE:MARGE + w][pied] = p[pied]
        q, sujet_q = lire(direction)
        yq = np.arange(q.shape[0])[:, None]
        tete = sujet_q & ((yq <= ty + 2) | ((yq <= ty + SOUS_TETE) & ~pieds_trepied(q)))
        tete = ndimage.binary_opening(tete, iterations=1)
        ys_t, xs_t = np.nonzero(tete)
        dx, dy = MARGE + px - tx, MARGE + py - ty
        toile[ys_t + dy, xs_t + dx] = q[ys_t, xs_t]
        Image.fromarray(toile.astype(np.uint8)).save(os.path.join(SORTIE, "base_turret_%s.png" % direction))
        print("base_turret_%s.png" % direction)


if __name__ == "__main__":
    main()
