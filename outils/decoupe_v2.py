#!/usr/bin/env python3
"""Découpe les planches docs/raw/V2 (fond magenta) en images détourées pour le jeu.

Usage :
    python3 outils/decoupe_v2.py apercu DOSSIER   # morceaux numérotés de chaque planche (pour régler MORCEAUX)
    python3 outils/decoupe_v2.py                  # écrit images/<famille>.png, data/atlas.gd et docs/apercu_atlas.jpg

Pour chaque morceau voulu (liste MORCEAUX) :
1. fond = magenta pur, OU mélange magenta + image cible (certaines planches contiennent
   docs/reference/original.png incrustée, alignée pixel pour pixel), OU voile violet ;
2. on garde, dans le polygone du morceau, la plus grande zone dessinée et ses trous intérieurs ;
3. « clair extérieur » (héros, objets) : le faisceau peint et la lueur jaune/rose sont retirés
   en remplissant depuis l'extérieur jusqu'au contour noir (la peau, à l'intérieur, est gardée) ;
4. bord adouci, teinte magenta retirée sur le bord, réduction à l'échelle de la famille ;
5. les morceaux d'une famille sont rangés dans un atlas (une seule texture par famille).
Besoin : numpy, pillow, scipy.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as nd

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
V2 = os.path.join(RACINE, "docs", "raw", "V2")
CIBLE = os.path.join(RACINE, "docs", "reference", "original.png")
MAGENTA = np.array([255.0, 0.0, 255.0])

PLANCHES = {
    "heros": "1792875089707.jpg",
    "zombies": "1792875094677.jpg",
    "sol_murs": "1792875099443.jpg",
    "decor": "1792875104157.jpg",
    "objets": "1792875108707.jpg",
    "portes": "1792875113408.jpg",
}

# Familles : planche, échelle (texture = 2x la taille à l'écran, pour la tablette), options
FAMILLES = {
    "heros": ("heros", 0.42, {"clair_exterieur": True}),
    "zombies": ("zombies", 0.6, {"yeux": True}),
    "sol": ("sol_murs", 0.6, {}),
    "murs": ("sol_murs", 0.6, {}),
    "decor": ("decor", 0.6, {}),
    "objets": ("objets", 0.3, {"clair_exterieur": True, "lueur": True}),
    "portes": ("portes", 0.5, {}),
}


def R(x0, y0, x1, y1):
    """Rectangle, en coordonnées de l'aperçu (moitié de la planche)."""
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


# Morceaux voulus : famille -> [(nom, polygone en coordonnées d'aperçu[, options propres au morceau])]
MORCEAUX = {
    "heros": [
        ("face_droite_1", R(58, 35, 208, 312)),
        ("face_droite_2", R(212, 36, 420, 306)),
        ("dos_droite_1", R(428, 36, 620, 300)),
        ("dos_1", R(748, 34, 864, 306)),
        ("dos_2", R(957, 36, 1070, 302)),
        ("dos_droite_2", R(1153, 36, 1309, 305)),
        ("face_1", R(45, 392, 175, 682)),
        ("face_2", R(248, 394, 368, 676)),
        ("dos_droite_3", R(400, 392, 585, 642)),
        ("profil_1", R(734, 414, 907, 707)),
        ("profil_2", R(919, 414, 1104, 695)),
        ("profil_3", R(1117, 414, 1299, 695)),
    ],
    "zombies": [
        ("gros_face_1", R(68, 14, 177, 196)),
        ("gros_face_2", R(287, 12, 403, 198)),
        ("gros_face_3", R(512, 14, 622, 196)),
        ("gros_dos_1", R(754, 12, 864, 194)),
        ("gros_dos_2", R(980, 12, 1090, 194)),
        ("gros_dos_profil", R(1204, 12, 1320, 194)),
        ("gros_face_4", R(68, 208, 177, 390)),
        ("gros_face_5", R(293, 208, 400, 391)),
        ("gros_dos_3", R(752, 206, 866, 384)),
        ("gros_dos_4", R(978, 208, 1088, 386)),
        ("gros_profil", R(1202, 208, 1307, 390)),
        ("maigre_face_1", R(78, 403, 159, 571)),
        ("maigre_face_2", R(302, 404, 386, 574)),
        ("maigre_face_3", R(532, 404, 613, 571)),
        ("maigre_dos_1", R(765, 403, 852, 571)),
        ("maigre_dos_2", R(996, 403, 1079, 572)),
        ("maigre_profil_1", R(1218, 404, 1301, 571)),
        ("maigre_face_4", R(72, 588, 151, 755)),
        ("maigre_face_5", R(301, 589, 382, 755)),
        ("maigre_face_6", R(528, 588, 609, 755)),
        ("maigre_profil_2", R(768, 588, 851, 755)),
        ("maigre_dos_3", R(999, 587, 1078, 756)),
        ("maigre_profil_3", R(1226, 588, 1308, 756)),
    ],
    "sol": [
        ("dalle", R(30, 18, 352, 226)),
        ("dalle_fissuree", R(364, 18, 682, 222)),
        ("dalle_tache", [(852, 16), (1014, 110), (1014, 126), (852, 214), (690, 126), (690, 110)]),
        ("dalle_flaque", [(852, 200), (1014, 280), (1014, 388), (690, 388), (690, 280)]),
        ("dalle_gravats", [(1178, 16), (1342, 110), (1342, 126), (1178, 214), (1016, 126), (1016, 110)]),
        ("dalle_papiers", [(1178, 196), (1342, 280), (1342, 388), (1016, 388), (1016, 280)]),
    ],
    "murs": [
        ("mur", R(48, 360, 342, 742)),
        ("mur_coin", R(384, 362, 670, 744)),
        ("mur_fenetre", R(712, 356, 1002, 740)),
        ("mur_porte", R(1040, 356, 1330, 740)),
    ],
    "decor": [
        ("caisse_grande", R(36, 24, 286, 330)),
        ("caisse", [(122, 440), (205, 398), (284, 434), (284, 528), (200, 570), (122, 532)]),
        ("etagere_longue", [(465, 36), (532, 36), (774, 164), (776, 374), (700, 374), (560, 302), (560, 214), (478, 128)]),
        ("etagere", R(745, 22, 910, 226)),
        ("etagere_courte", R(786, 224, 972, 412)),
        ("etagere_renversee", R(978, 98, 1342, 364)),
        ("carton_ouvert", R(434, 388, 618, 568)),
        ("carton_ecrase", R(638, 404, 792, 558)),
        ("carton", [(858, 468), (940, 424), (1030, 466), (1030, 592), (950, 626), (858, 584)]),
        ("congelateur", [(1002, 440), (1100, 384), (1318, 494), (1318, 604), (1206, 682), (1034, 600), (1034, 468)]),
        ("debris_planches", R(336, 568, 594, 710)),
        ("debris_carton", R(666, 582, 892, 740)),
        ("debris_papiers", R(0, 532, 152, 612)),
        ("debris_bout", R(972, 642, 1050, 692)),
        ("debris_planche", R(1028, 700, 1098, 736)),
    ],
    "objets": [
        ("conserve", R(82, 42, 298, 356)),
        ("trousse", R(372, 48, 688, 348)),
        ("piles", [(722, 60), (988, 60), (988, 212), (950, 212), (950, 344), (722, 344)]),
        ("cle", R(1042, 42, 1320, 344)),
        ("eau", R(40, 380, 330, 680), {"sans_violet": True}),   # plastique mauve : pas de filtre violet
        ("talkie", R(376, 378, 670, 680)),
        ("couteau", R(668, 378, 956, 680)),
        ("carte", R(944, 392, 1352, 680)),
    ],
    "portes": [
        ("porte_fermee", [(112, 205), (540, 22), (582, 42), (582, 150), (572, 160), (572, 424), (150, 616), (112, 596)]),
        ("porte_ouverte", [(726, 205), (1148, 26), (1186, 46), (1220, 205), (1220, 502), (1004, 600), (760, 614), (726, 600)]),
    ],
}

_cache = {}


def planche(cle):
    if cle not in _cache:
        _cache[cle] = np.asarray(Image.open(os.path.join(V2, PLANCHES[cle])).convert("RGB")).astype(float)
    return _cache[cle]


def masque_fond(p, o, violet_actif=True):
    """Vrai là où le pixel est du fond (magenta, incrustation ou voile violet) ; et magenta pur."""
    dm = np.linalg.norm(p - MAGENTA, axis=-1)
    v = o - MAGENTA
    a = np.clip(((p - MAGENTA) * v).sum(-1) / np.maximum((v * v).sum(-1), 1), 0, 1)
    residu = np.linalg.norm(p - MAGENTA - a[..., None] * v, axis=-1)
    r, g, b = p[..., 0], p[..., 1], p[..., 2]
    violet = (b - g > 35) & (b > r - 15) & (b > 120) & (r > 70)   # voile clair (le jean, foncé, reste)
    if not violet_actif:
        violet = np.zeros_like(violet)
    return (dm < 90) | ((residu < 30) & (a < 0.75)) | violet, dm < 110


def clair(p):
    """Faisceau peint (jaune pâle, rose) et lueur des objets (jaune vif, rose)."""
    r, g, b = p[..., 0], p[..., 1], p[..., 2]
    return (r > 190) & ((g > 130) | (b > 130))


def lueur(p):
    """Lueur jaune vif ou rose des objets, même enfermée (anneau de la clé)."""
    r, g, b = p[..., 0], p[..., 1], p[..., 2]
    return (r > 200) & (((g > 180) & (b < 90)) | ((b > 140) & (g < 170)))


def yeux(p):
    """Grands yeux jaunes des zombies."""
    r, g, b = p[..., 0], p[..., 1], p[..., 2]
    return (r > 190) & (g > 170) & (b < 160) & (r - b > 70)


def extraire(cle_planche, polygone, options):
    p_tout = planche(cle_planche)
    if "cible" not in _cache:
        _cache["cible"] = np.asarray(Image.open(CIBLE).convert("RGB")).astype(float)
    poly = [(x * 2, y * 2) for x, y in polygone]
    xs, ys = [x for x, _ in poly], [y for _, y in poly]
    x0, y0 = max(int(min(xs)), 0), max(int(min(ys)), 0)
    x1, y1 = min(int(max(xs)) + 1, p_tout.shape[1]), min(int(max(ys)) + 1, p_tout.shape[0])
    p = p_tout[y0:y1, x0:x1]
    dedans = Image.new("L", (x1 - x0, y1 - y0), 0)
    ImageDraw.Draw(dedans).polygon([(x - x0, y - y0) for x, y in poly], fill=255)
    dedans = np.asarray(dedans) > 0
    fond, magenta_pur = masque_fond(p, _cache["cible"][y0:y1, x0:x1], not options.get("sans_violet"))
    fond |= ~dedans
    if options.get("clair_exterieur"):
        # Remplissage depuis l'extérieur à travers le fond et les pixels clairs
        traversable = fond | clair(p)
        etiquettes, _ = nd.label(traversable)
        bords = np.unique(np.concatenate([etiquettes[0], etiquettes[-1], etiquettes[:, 0], etiquettes[:, -1]]))
        exterieur = np.isin(etiquettes, bords[bords > 0]) | fond
        fond = exterieur
    dessin = nd.binary_opening(~fond, iterations=2)
    etiquettes, n = nd.label(nd.binary_closing(dessin, iterations=3) & dedans)
    if n == 0:
        return None
    tailles = nd.sum(dessin, etiquettes, range(1, n + 1))
    zone = etiquettes == np.argmax(tailles) + 1
    garde = nd.binary_fill_holes(zone) & ~magenta_pur & dedans
    garde &= dessin | nd.binary_fill_holes(zone & dessin)
    if options.get("clair_exterieur"):
        garde &= ~fond
    if options.get("lueur"):
        garde &= ~nd.binary_dilation(lueur(p), iterations=1)
    # Bord doux, puis teinte magenta retirée près du bord
    alpha = nd.gaussian_filter(garde.astype(float), 0.8)
    alpha[~nd.binary_dilation(garde)] = 0
    rgb = p.copy()
    bord = nd.binary_dilation(garde) & ~nd.binary_erosion(garde, iterations=3)
    m = np.minimum(rgb[..., 0], rgb[..., 2])
    exces = np.clip(m - rgb[..., 1] - 20, 0, None) * bord
    rgb[..., 0] -= exces
    rgb[..., 2] -= exces
    rgba = np.dstack([np.clip(rgb, 0, 255), alpha * 255]).astype(np.uint8)
    image = Image.fromarray(rgba)
    boite = image.getbbox()
    image = image.crop(boite)
    calque_yeux = None
    if options.get("yeux"):
        oeil = yeux(p) & garde
        oeil[int(oeil.shape[0] * 0.4):] = False   # les yeux sont dans le haut du corps
        # On garde les deux plus grosses taches (les deux yeux)
        etiquettes, n = nd.label(oeil)
        if n:
            tailles = nd.sum(oeil, etiquettes, range(1, n + 1))
            oeil = np.isin(etiquettes, np.argsort(tailles)[-2:] + 1)
        oeil = nd.binary_dilation(oeil, iterations=2) & garde
        a = np.zeros(oeil.shape, np.uint8)
        a[oeil] = 255
        calque_yeux = Image.fromarray(np.dstack([rgba[..., :3], a])).crop(boite)
        boite_yeux = calque_yeux.getbbox()
        if boite_yeux:
            # Recadré sur les yeux ; décalage par rapport au coin de l'image du corps
            calque_yeux = (calque_yeux.crop(boite_yeux), boite_yeux[:2])
        else:
            calque_yeux = None
    return image, calque_yeux


def reprendre_coin(image, propre):
    """Le coin du haut de cette dalle était caché par la dalle de derrière : on le reprend
    sur la dalle propre (même forme), mis à la même taille."""
    modele = propre.resize(image.size, Image.LANCZOS)
    w, h = image.size
    coin = Image.new("L", image.size, 0)
    ImageDraw.Draw(coin).polygon([(w * 0.5, 0), (w * 0.72, h * 0.13), (w * 0.28, h * 0.13)], fill=255)
    image.paste(modele, (0, 0), coin)


def reduire(image, echelle):
    taille = (max(1, round(image.width * echelle)), max(1, round(image.height * echelle)))
    return image.resize(taille, Image.LANCZOS)


def ranger(images, largeur_max=2048, marge=2):
    """Rangement en étagères : renvoie (largeur, hauteur, {nom: (x, y)})."""
    ordre = sorted(images, key=lambda n: -images[n].height)
    x = y = haut = 0
    places = {}
    largeur = 0
    for nom in ordre:
        im = images[nom]
        if x + im.width + marge > largeur_max:
            x, y, haut = 0, y + haut + marge, 0
        places[nom] = (x, y)
        x += im.width + marge
        largeur = max(largeur, x)
        haut = max(haut, im.height)
    return largeur, y + haut, places


def construire():
    os.makedirs(os.path.join(RACINE, "images"), exist_ok=True)
    regions = {}
    decalages = {}
    apercus = []
    for famille, (cle_planche, echelle, options) in FAMILLES.items():
        images = {}
        for nom, polygone, *propres in MORCEAUX[famille]:
            resultat = extraire(cle_planche, polygone, dict(options, **(propres[0] if propres else {})))
            if resultat is None:
                print("  manquant :", famille, nom)
                continue
            image, calque_yeux = resultat
            images[nom] = reduire(image, echelle)
            if calque_yeux is not None:
                images[nom + "_yeux"] = reduire(calque_yeux[0], echelle)
                decalages[nom + "_yeux"] = (round(calque_yeux[1][0] * echelle), round(calque_yeux[1][1] * echelle))
        if famille == "sol":
            for nom in ("dalle_flaque", "dalle_papiers"):
                reprendre_coin(images[nom], images["dalle"])
        largeur, hauteur, places = ranger(images)
        atlas = Image.new("RGBA", (largeur, hauteur), (0, 0, 0, 0))
        for nom, (x, y) in places.items():
            atlas.alpha_composite(images[nom], (x, y))
            regions[nom] = (famille, x, y, images[nom].width, images[nom].height, decalages.get(nom, (0, 0)))
        atlas.save(os.path.join(RACINE, "images", famille + ".png"), optimize=True)
        apercus.append((famille, atlas))
        print(famille, len(images), "images,", largeur, "x", hauteur)
    ecrire_atlas_gd(regions)
    ecrire_apercu(apercus)


def ecrire_atlas_gd(regions):
    lignes = [
        "extends Node",
        "## FICHIER GÉNÉRÉ par outils/decoupe_v2.py : ne pas modifier à la main.",
        "## Images détourées des planches docs/raw/V2, rangées dans un atlas par famille (images/<famille>.png).",
        "## Chaque image : [famille, région dans l'atlas, décalage]. Les images « _yeux » ne contiennent",
        "## que les yeux (à dessiner sans être assombris par la nuit), au décalage donné dans l'image du corps.",
        "",
        "const REGIONS := {",
    ]
    for nom in sorted(regions):
        famille, x, y, w, h, (dx, dy) = regions[nom]
        lignes.append('\t"%s": ["%s", Rect2(%d, %d, %d, %d), Vector2(%d, %d)],' % (nom, famille, x, y, w, h, dx, dy))
    lignes.append("}")
    with open(os.path.join(RACINE, "data", "atlas.gd"), "w") as f:
        f.write("\n".join(lignes) + "\n")


def ecrire_apercu(apercus):
    largeur = max(a.width for _, a in apercus)
    hauteur = sum(a.height + 60 for _, a in apercus)
    fond = Image.new("RGBA", (largeur, hauteur), (34, 30, 51, 255))
    dessin = ImageDraw.Draw(fond)
    y = 0
    for famille, atlas in apercus:
        dessin.text((10, y + 10), famille, fill=(248, 233, 137, 255), font_size=40)
        fond.alpha_composite(atlas, (0, y + 60))
        y += atlas.height + 60
    fond = fond.convert("RGB").resize((fond.width // 2, fond.height // 2), Image.LANCZOS)
    fond.save(os.path.join(RACINE, "docs", "apercu_atlas.jpg"), quality=85)


def apercu(dossier):
    """Morceaux de chaque planche, encadrés et numérotés, pour régler MORCEAUX."""
    os.makedirs(dossier, exist_ok=True)
    for famille, (cle_planche, _, options) in FAMILLES.items():
        fond = Image.new("RGBA", (2752, 1536), (40, 160, 60, 255))
        dessin = ImageDraw.Draw(fond)
        for nom, polygone, *propres in MORCEAUX[famille]:
            resultat = extraire(cle_planche, polygone, dict(options, **(propres[0] if propres else {})))
            poly = [(x * 2, y * 2) for x, y in polygone]
            dessin.polygon(poly, outline=(255, 255, 0, 255), width=3)
            if resultat:
                image = resultat[0]
                x0 = int(min(x for x, _ in poly))
                y0 = int(min(y for _, y in poly))
                # position approximative (la boîte recadrée part du coin du polygone)
                fond.alpha_composite(image, (x0, y0))
            dessin.text((poly[0][0] + 6, poly[0][1] + 4), nom, fill=(255, 255, 255, 255), font_size=36)
        fond.convert("RGB").resize((1376, 768)).save(os.path.join(dossier, famille + ".png"))
        print(famille)


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "apercu":
        apercu(sys.argv[2])
    else:
        construire()
