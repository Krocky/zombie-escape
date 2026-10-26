"""Découpe une planche V4 (même personnage en 3 poses côte à côte sur fond magenta) en 3 images.

    python3 tools/decoupe_planche.py docs/raw/V4/planches/survivor_girl.jpg

Écrit docs/raw/V4/<nom>_hiding.png, _follow.png, _happy.png (de gauche à droite), chacune entourée
d'une marge de fond, prêtes pour tools/process_assets.py --source docs/raw/V4.
Les 3 plus grandes taches de pixels reliés sont les poses ; les petits morceaux détachés vont à la
pose la plus proche. Les autres poses sont repeintes en fond (une canne levée peut passer au-dessus
de la voisine)."""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

POSES = ["hiding", "follow", "happy"]
MARGE = 40


def decouper(chemin):
    img = Image.open(chemin).convert("RGB")
    p = np.asarray(img).astype(int)
    r, g, b = p[..., 0], p[..., 1], p[..., 2]
    sujet = ~((r - g > 100) & (b - g > 100))            # tout ce qui n'est pas magenta
    sujet = ndimage.binary_opening(sujet, iterations=2)  # bruit du JPEG
    etiquettes, n = ndimage.label(sujet, structure=np.ones((3, 3)))
    surfaces = ndimage.sum(sujet, etiquettes, index=np.arange(1, n + 1))
    grandes = list(np.argsort(-surfaces)[:len(POSES)] + 1)
    if len(grandes) < len(POSES) or surfaces[grandes[-1] - 1] < 0.05 * surfaces.sum():
        sys.exit("%s : les poses se touchent" % chemin)
    grandes.sort(key=lambda e: ndimage.center_of_mass(sujet, etiquettes, e)[1])   # de gauche à droite
    centres = [ndimage.center_of_mass(sujet, etiquettes, e)[1] for e in grandes]
    # Petits morceaux détachés (doudou, bout de canne) : à la pose la plus proche
    pose_de = np.zeros(n + 1, dtype=int)
    for e in range(1, n + 1):
        cx = ndimage.center_of_mass(sujet, etiquettes, e)[1] if e not in grandes else None
        pose_de[e] = grandes.index(e) if e in grandes else int(np.argmin([abs(cx - c) for c in centres]))
    nom = os.path.splitext(os.path.basename(chemin))[0]
    sortie = os.path.dirname(os.path.dirname(chemin))
    fond = np.median(p[:20, :20].reshape(-1, 3), axis=0).astype(np.uint8)
    for i, pose in enumerate(POSES):
        masque = (pose_de[etiquettes] == i) & (etiquettes > 0)
        masque = ndimage.binary_dilation(masque, iterations=6)   # garde le liseré mêlé au fond
        ys, xs = np.nonzero(masque)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        morceau = np.where(masque[..., None], p, fond).astype(np.uint8)[y0:y1, x0:x1]
        toile = np.zeros((y1 - y0 + 2 * MARGE, x1 - x0 + 2 * MARGE, 3), np.uint8)
        toile[:] = fond
        toile[MARGE:-MARGE, MARGE:-MARGE] = morceau
        fichier = os.path.join(sortie, "%s_%s.png" % (nom, pose))
        Image.fromarray(toile).save(fichier)
        print(fichier, toile.shape[1::-1])


if __name__ == "__main__":
    for c in sys.argv[1:]:
        decouper(c)
