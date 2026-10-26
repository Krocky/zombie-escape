"""Découpe une planche V4 (même personnage en plusieurs poses côte à côte sur fond magenta) en une image par pose.

    python3 tools/decoupe_planche.py docs/raw/V4/planches/survivor_girl.jpg
    python3 tools/decoupe_planche.py docs/raw/V4/planches/zombie_big_profil.jpg --nom zombie_big --poses iddle,walk_a,walk_b,attack

Écrit docs/raw/V4/<nom>_<pose>.png de gauche à droite (défaut : nom du fichier, poses hiding, follow, happy), chacune entourée
d'une marge de fond, prêtes pour tools/process_assets.py --source docs/raw/V4.
Les N plus grandes taches de pixels reliés sont les poses ; les petits morceaux détachés vont à la
pose la plus proche. Les autres poses sont repeintes en fond (une canne levée peut passer au-dessus
de la voisine)."""
import argparse
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

POSES = ["hiding", "follow", "happy"]   # défaut : les 3 poses d'un rescapé
MARGE = 40


def decouper(chemin, nom=None, poses=POSES):
    img = Image.open(chemin).convert("RGB")
    p = np.asarray(img).astype(int)
    r, g, b = p[..., 0], p[..., 1], p[..., 2]
    sujet = ~((r - g > 100) & (b - g > 100))            # tout ce qui n'est pas magenta
    sujet = ndimage.binary_opening(sujet, iterations=2)  # bruit du JPEG
    etiquettes, n = ndimage.label(sujet, structure=np.ones((3, 3)))
    surfaces = ndimage.sum(sujet, etiquettes, index=np.arange(1, n + 1))
    grandes = list(np.argsort(-surfaces)[:len(poses)] + 1)
    if len(grandes) < len(poses) or surfaces[grandes[-1] - 1] < 0.05 * surfaces.sum():
        sys.exit("%s : les poses se touchent" % chemin)
    grandes.sort(key=lambda e: ndimage.center_of_mass(sujet, etiquettes, e)[1])   # de gauche à droite
    centres = [ndimage.center_of_mass(sujet, etiquettes, e)[1] for e in grandes]
    # Petits morceaux détachés (doudou, bout de canne) : à la pose la plus proche
    pose_de = np.zeros(n + 1, dtype=int)
    for e in range(1, n + 1):
        cx = ndimage.center_of_mass(sujet, etiquettes, e)[1] if e not in grandes else None
        pose_de[e] = grandes.index(e) if e in grandes else int(np.argmin([abs(cx - c) for c in centres]))
    nom = nom or os.path.splitext(os.path.basename(chemin))[0]
    sortie = os.path.dirname(os.path.dirname(chemin))
    fond = np.median(p[:20, :20].reshape(-1, 3), axis=0).astype(np.uint8)
    for i, pose in enumerate(poses):
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
    ap = argparse.ArgumentParser()
    ap.add_argument("planches", nargs="+")
    ap.add_argument("--nom", help="début du nom des images (défaut : nom de la planche)")
    ap.add_argument("--poses", default=",".join(POSES), help="poses de gauche à droite, séparées par des virgules")
    args = ap.parse_args()
    for c in args.planches:
        decouper(c, args.nom, args.poses.split(","))
