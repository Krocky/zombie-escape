#!/usr/bin/env python3
"""Détoure les images générées (Gemini, fond magenta #FF00FF) et les prépare pour le jeu.

Usage :
    python3 tools/process_assets.py            # traite seulement les nouveautés de docs/raw/V3
    python3 tools/process_assets.py --liste    # montre les nouveautés sans rien traiter
    python3 tools/process_assets.py --tout     # retraite tout (après un changement de réglage)
    options : --source docs/raw/V3 --sortie images/v3 --tolerance 60 --douceur 70 --ouverture 4

Nouveauté = image absente de manifest.json, ou dont le fichier a changé (empreinte SHA-1 gardée
dans le manifest). Un personnage déjà traité garde son échelle (echelles_perso du manifest) :
ses nouvelles poses sortent à la même taille que les anciennes.

Pour chaque image (.png, .jpg) du dossier source (jamais modifié ni supprimé ; les sous-dossiers,
archives, sont ignorés) :
1. contrôle du fond : couleur médiane des coins, acceptée si elle est uniforme sur les bords et de
   teinte magenta (rouge et bleu > vert + 100 : magenta pur, délavé ou mauve) ; un faux damier de
   transparence (gris/blanc) est signalé et l'image n'est pas traitée ;
2. clé couleur : distance à la couleur de fond mesurée < tolérance = transparent, puis une zone de
   transition (« douceur ») où l'alpha monte et où la couleur est démélangée du fond ;
3. ombres violettes (ombre peinte en magenta sombre, fumée violette) reliées au fond : noir
   semi-transparent, opacité = assombrissement par rapport au fond ; teinte violette légère reliée
   au fond (bord du tapis, lueur) : désaturée (props, carte, murs) ou effacée (items) ; mauve
   enfermé (ombre peinte sur le tapis des base_, sol vu à travers un objet) : désaturé ;
4. défrangeage : sur les 3 px du bord, la teinte magenta restante est retirée (liseré rose,
   surtout dû à la compression JPEG) ; poussières isolées et traits très fins supprimés ;
5. personnages : le faisceau de lampe peint (clair, hors du contour noir) est retiré, le jeu
   dessine le sien ; les taches détachées du corps (< 2 % de sa surface) sont effacées ;
6. props à socle de dalles (SOCLE) : socle effacé depuis l'extérieur, ombre elliptique douce ;
7. rognage au contenu, puis taille selon le préfixe du nom (voir CATEGORIES) ;
6. floor_ : texture carrée vue de dessus -> losange isométrique de la taille des dalles du jeu
   (rotation 45°, écrasement vertical à Iso.RAPPORT) ;
7. écriture dans le dossier de sortie (nom en minuscules, « - » -> « _ ») et mise à jour de
   manifest.json (taille, ancre aux pieds, coins au sol, anomalies).
Besoin : Python 3, numpy, pillow, scipy.
"""
import argparse
import glob
import hashlib
import json
import os
import re

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAGENTA = np.array([255.0, 0.0, 255.0])

# Grille isométrique du jeu (scripts/iso.gd, scripts/niveau.gd)
ISO_K = 0.6
ISO_RAPPORT = 0.588                      # hauteur / largeur d'un losange (1,7:1, pas 2:1)
CASE = 200.0                             # une dalle couvre une case du monde
LARGEUR_CASE_ECRAN = 2 * CASE * ISO_K    # 240 px à l'écran
TEXTURE_X = 2                            # textures à 2x la taille à l'écran (tablette)

# Dalle : même largeur que les dalles V2 de l'atlas (~385 px), losange exact
DALLE_LARGEUR = 384
DALLE_HAUTEUR = round(DALLE_LARGEUR * ISO_RAPPORT)   # 226

# Hauteur (pose debout) des personnages, en pixels de texture : le héros V2 fait ~240 px
# (affiché à 0,5 dans le jeu), le zombie maigre ~200, le gros ~217.
HAUTEURS = {"heros": 240, "heroine": 240, "survivor": 230, "zombie": 210}

# Préfixe -> catégorie
CATEGORIES = {
    "heros": "perso", "heroine": "perso", "zombie": "perso", "survivor": "perso",
    "item": "item", "icon": "icon", "prop": "prop", "base": "prop", "bg": "bg", "floor": "floor",
    "map": "map", "wall": "wall",
}
COTE = {"item": 128, "icon": 192}        # plus grand côté
BG_MAX = 2048
MAP_LARGEUR = 400                        # vignettes de la carte (largeur)
COTE_NOM = {"map_lock": 192}             # exceptions : plus grand côté
# Murs : même échelle que le pan V2 « mur » de l'atlas (data/atlas.gd, 349 px de large pour un pan
# de Mur.LONGUEUR_PANNEAU = 200 unités monde) : un wall_ = un pan.
MUR_LARGEUR = 349
# Mât très haut et fin : mis à l'échelle sur la hauteur (x base_shelter_1), pas sur la largeur
HAUTEUR_RELATIVE = {"base_floodlight": ("base_shelter_1", 1.4)}

# Fond accepté : rouge et bleu au-dessus du vert d'au moins FOND_ECART (magenta pur, délavé, mauve)
FOND_ECART = 100
# Props posés sur un socle de dalles bleu-gris (joints noirs) à effacer ; les base_ gardent leur tapis
SOCLE = {"prop_sofa_2c", "prop_bed_2c", "prop_fridge", "prop_kitchen_table_2c", "prop_shelf_food_2c",
         "prop_freezer", "prop_checkout_2c", "prop_pallet", "prop_neon"}
SOCLE_COULEUR = np.array([52.0, 57.0, 82.0])
TACHE_PART = 0.02                        # personnages : taches détachées < 2 % de la surface effacées

# Mots de pose : ce qui les précède nomme le personnage (Heros-walk-a -> heros, même échelle
# pour toutes ses poses : la hauteur médiane de ses poses vaut HAUTEURS[préfixe]).
POSES = {"idle", "iddle", "walk", "run", "attack", "hit", "hurt", "death", "die", "dead",
         "hide", "hiding", "follow", "happy", "back", "front", "side", "a", "b", "c", "d", "1", "2", "3", "4"}


def categorie(nom):
    m = re.match(r"([a-z]+)[-_]", nom.lower())
    if not m or m.group(1) not in CATEGORIES:
        return None, None
    return m.group(1), CATEGORIES[m.group(1)]


def personnage(nom):
    mots = re.split(r"[-_]", nom.lower())
    garde = []
    for mot in mots:
        if mot in POSES and garde:
            break
        garde.append(mot)
    return "_".join(garde)


# --- Contrôle du fond ---------------------------------------------------------------------

def examiner_fond(p, tolerance):
    """Regarde une bande de 4 % sur les bords : ('magenta', couleur mesurée, part), ('damier', ...)
    ou ('inconnu', ...). Couleur = médiane des 4 coins ; acceptée si au moins 60 % des bords en
    sont proches et si elle est de teinte magenta (rouge et bleu > vert + FOND_ECART)."""
    h, w, _ = p.shape
    m = max(4, int(min(h, w) * 0.04))
    bord = np.concatenate([p[:m].reshape(-1, 3), p[-m:].reshape(-1, 3),
                           p[:, :m].reshape(-1, 3), p[:, -m:].reshape(-1, 3)])
    coins = np.concatenate([p[:m, :m].reshape(-1, 3), p[:m, -m:].reshape(-1, 3),
                            p[-m:, :m].reshape(-1, 3), p[-m:, -m:].reshape(-1, 3)])
    couleur = np.median(coins, axis=0)
    part = float((np.linalg.norm(bord - couleur, axis=-1) < tolerance / 2).mean())
    teinte = couleur[0] - couleur[1] >= FOND_ECART and couleur[2] - couleur[1] >= FOND_ECART
    if part > 0.6 and teinte:
        return "magenta", couleur, part
    part_magenta = float((np.linalg.norm(bord - MAGENTA, axis=-1) < tolerance).mean())
    # Damier : gris neutres clairs, sur deux niveaux, qui alternent
    neutre = (bord.max(-1) - bord.min(-1) < 24) & (bord.mean(-1) > 110)
    if neutre.mean() > 0.6:
        lum = bord[neutre].mean(-1)
        if np.percentile(lum, 90) - np.percentile(lum, 10) > 12:
            return "damier", None, part_magenta
    return "inconnu", None, part_magenta


def damier_interieur(p, alpha):
    """Damier gris/blanc gardé dans le dessin (fond pas magenta derrière le sujet) : grandes
    zones neutres claires à deux niveaux qui alternent tous les ~16-64 px."""
    neutre = (p.max(-1) - p.min(-1) < 10) & (p.mean(-1) > 150) & (alpha > 0.5)
    if neutre.mean() < 0.08:
        return False
    lum = np.where(neutre, p.mean(-1), np.nan)
    # Alternance le long des lignes : sauts francs (> 15) entre pixels neutres voisins
    d = np.abs(np.diff(lum, axis=1))
    sauts = np.nansum(d > 15) / max(1, np.sum(~np.isnan(d)))
    return 0.01 < sauts < 0.2 and neutre.mean() > 0.15


# --- Détourage ------------------------------------------------------------------------------

def detourer(p, fond, tolerance, douceur):
    """Clé couleur sur le fond mesuré + démélange : renvoie rgb (float) et alpha (0..1)."""
    dm = np.linalg.norm(p - fond, axis=-1)
    alpha = np.clip((dm - tolerance) / douceur, 0, 1)
    rgb = p.copy()
    partiel = (alpha > 0) & (alpha < 1)
    a = alpha[partiel][:, None]
    rgb[partiel] = np.clip(fond + (p[partiel] - fond) / a, 0, 255)
    return rgb, alpha


def ombres_violettes(p, fond, rgb, alpha):
    """Ombres peintes en magenta sombre (ellipse sous l'objet) et fumée violette : chaque pixel de
    teinte magenta (rouge et bleu nettement au-dessus du vert) relié au fond devient noir, d'opacité
    = son assombrissement par rapport au fond (p = (1 - a) x fond + a x noir). Les pixels magenta
    enfermés dans le dessin (contour noir) ne sont touchés que s'ils sont francs. Renvoie le masque."""
    r, g, b = p[..., 0], p[..., 1], p[..., 2]
    m = np.minimum(r, b)
    violet = (m - g > 40) & (g < 0.4 * m)
    etiquettes, _ = ndimage.label(violet | (alpha == 0), structure=np.ones((3, 3)))
    relies = np.unique(etiquettes[alpha == 0])
    # Enfermés dans le dessin (fond vu entre les barreaux d'un caddie) : teinte franche seulement
    franc = (m - g > 60) & (g < 0.25 * m)
    violet &= (np.isin(etiquettes, relies[relies > 0]) | franc) & (alpha > 0)
    clarte = (r + b) / 2.0
    a = np.clip(1.0 - clarte / ((fond[0] + fond[2]) / 2.0), 0, 1)
    rgb[violet] = 0
    alpha[violet] = a[violet]
    return violet


def devioler(p, rgb, alpha, violet, effacer):
    """Teinte violette légère (bord du tapis de terre, ombre peinte en transparence sur le sol,
    lueur rose autour d'un objet) reliée au fond : l'excès de rouge et de bleu sur le vert est
    retiré (le pixel devient gris-brun), ou le pixel est effacé (« effacer » : lueur d'un item)."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    m = np.minimum(r, b)
    teinte = (m - g > 25) & (alpha > 0) & ~violet
    etiquettes, _ = ndimage.label(teinte | violet | (alpha == 0), structure=np.ones((3, 3)))
    relies = np.unique(etiquettes[alpha == 0])
    teinte &= np.isin(etiquettes, relies[relies > 0])
    if effacer:
        alpha[teinte] = 0
    else:
        exces = np.clip(m - g - 10, 0, None)[teinte]
        rgb[..., 0][teinte] -= exces
        rgb[..., 2][teinte] -= exces
    return int(teinte.sum())


def desaturer_mauve(rgb, alpha, sombre_seulement):
    """Ombre violette peinte en transparence sur le tapis de terre (base_) ou vue à travers un
    objet (sol du caddie) : enfermée dans le dessin, elle échappe aux deux passes précédentes.
    Rouge et bleu tous deux au-dessus du vert de plus de 8 : ramenés vers le vert (gris-brun).
    Props : seulement les pixels sombres (les emballages roses et violets clairs sont gardés)."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    exces = np.minimum(r, b) - g
    mauve = (exces > 8) & (alpha > 0)
    if sombre_seulement:
        mauve &= rgb.max(-1) < 110
    rgb[..., 0][mauve] -= exces[mauve]
    rgb[..., 2][mauve] -= exces[mauve]
    return int(mauve.sum())


def taches(alpha, part):
    """Efface les morceaux non reliés au corps (le plus grand) et plus petits que part x surface."""
    etiquettes, n = ndimage.label(alpha > 0, structure=np.ones((3, 3)))
    if n < 2:
        return 0
    surfaces = ndimage.sum(alpha > 0.5, etiquettes, index=np.arange(1, n + 1))
    corps = int(np.argmax(surfaces)) + 1
    petits = [i + 1 for i, s in enumerate(surfaces) if i + 1 != corps and s < part * surfaces.sum()]
    retire = np.isin(etiquettes, petits)
    alpha[retire] = 0
    return int(retire.sum())


def effacer_socle(p, rgb, alpha, violet):
    """Socle de dalles bleu-gris (dessus ~63,68,99, tranche ~35,37,66, joints et contour noirs) :
    remplissage depuis l'extérieur sur les pixels de cette teinte (bleu > rouge ~ vert, sombres),
    l'ombre violette et les traits sombres qui les bordent ; le contour noir de l'objet (3 px contre
    ses pixels propres) est rendu. Puis ombre elliptique noire douce sous l'objet."""
    r, g, b = p[..., 0], p[..., 1], p[..., 2]
    bleute = (b - r > 15) & (b - r < 55) & (np.abs(r - g) < 14) & (p.max(-1) < 115) & (alpha > 0)
    sombre = (p.max(-1) < 75) & (alpha > 0)
    passable = bleute | violet | (alpha == 0) | (sombre & dilater(bleute, 6))
    etiquettes, _ = ndimage.label(passable)
    relies = np.unique(etiquettes[alpha == 0])
    retire = np.isin(etiquettes, relies[relies > 0]) & (alpha > 0)
    objet = (alpha > 0.5) & ~retire & ~sombre
    retire &= ~(sombre & ~violet & dilater(objet, 3))
    alpha[retire] = 0
    taches(alpha, 0.002)                 # miettes du socle restées collées au bord
    plein = alpha > 0.5
    if not plein.any():
        return int(retire.sum())
    ys, xs = np.nonzero(plein)
    x0, x1, yb = xs.min(), xs.max(), ys.max()
    larg = 0.85 * (x1 - x0)
    haut = larg * ISO_RAPPORT * 0.55
    larg, haut = float(larg), float(haut)
    cx, cy = (x0 + x1) / 2.0, yb - haut * 0.4
    h, w = alpha.shape
    ombre = Image.new("L", (w, h), 0)
    ImageDraw.Draw(ombre).ellipse([cx - larg / 2, cy - haut / 2, cx + larg / 2, cy + haut / 2], fill=120)
    ombre = np.asarray(ombre.filter(ImageFilter.GaussianBlur(float(haut * 0.18)))) / 255.0
    total = alpha + ombre * (1 - alpha)
    garde = total > 0
    rgb[garde] *= (alpha[garde] / total[garde])[:, None]
    alpha[:] = total
    return int(retire.sum())


def eroder(masque, rayon):
    im = Image.fromarray((masque * 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.MinFilter(2 * rayon + 1))) > 127


def dilater(masque, rayon):
    im = Image.fromarray((masque * 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.MaxFilter(2 * rayon + 1))) > 127


def defranger(rgb, alpha):
    """Retire la teinte magenta sur les 3 px du bord (le contour noir y redevient noir)."""
    plein = alpha > 0.5
    bord = (alpha > 0) & ~eroder(plein, 3)
    m = np.minimum(rgb[..., 0], rgb[..., 2])
    exces = np.clip(m - rgb[..., 1] - 20, 0, None) * bord
    rgb[..., 0] -= exces
    rgb[..., 2] -= exces
    return int(bord.sum())


def nettoyer(alpha):
    """Supprime les poussières : pixels presque seuls dans leur voisinage 9x9."""
    masque = Image.fromarray(((alpha > 0) * 255).astype(np.uint8))
    densite = np.asarray(masque.filter(ImageFilter.BoxBlur(4))) / 255.0
    seuls = (alpha > 0) & (densite < 0.2)
    alpha[seuls] = 0
    return int(seuls.sum())


def ouvrir(alpha, rayon):
    """Efface les traits plus fins que 2 x rayon px (restes du bord du faisceau, rayures du fond)
    sans toucher au reste : érosion puis dilatation du masque."""
    masque = alpha > 0
    garde = dilater(eroder(masque, rayon), rayon + 1)
    retire = masque & ~garde
    alpha[retire] = 0
    return int(retire.sum())


def connexe(graine, passable, pas_max=4000):
    """Pixels de « passable » reliés à « graine » (remplissage par dilatations successives)."""
    atteint = graine & passable
    for _ in range(pas_max):
        suivant = dilater(atteint, 1) & passable
        if (suivant == atteint).all():
            break
        atteint = suivant
    return atteint


def retirer_faisceau(rgb, alpha):
    """Faisceau peint : pixels clairs (jaune pâle, rose) reliés au fond sans traverser le
    contour noir. Travail à mi-résolution (plus rapide), masque ramené ensuite."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    clair = (alpha > 0) & (r > 190) & ((g > 130) | (b > 130))
    if clair.sum() < 50:
        return 0
    h, w = alpha.shape
    demi = (max(1, w // 2), max(1, h // 2))
    fond_d = np.asarray(Image.fromarray(((alpha == 0) * 255).astype(np.uint8)).resize(demi, Image.BOX)) > 127
    clair_d = np.asarray(Image.fromarray((clair * 255).astype(np.uint8)).resize(demi, Image.BOX)) > 60
    atteint = connexe(dilater(fond_d, 1), clair_d | fond_d) & ~fond_d
    retire = np.asarray(Image.fromarray((atteint * 255).astype(np.uint8)).resize((w, h), Image.NEAREST)) > 127
    retire = dilater(retire, 2) & clair
    alpha[retire] = 0
    return int(retire.sum())


# --- Mise en forme ---------------------------------------------------------------------------

def vers_image(rgb, alpha):
    return Image.fromarray(np.dstack([np.clip(rgb, 0, 255), alpha * 255]).astype(np.uint8))


def boite_utile(image):
    """Boîte du contenu, sans les pixels presque transparents."""
    a = image.getchannel("A").point(lambda v: 255 if v > 8 else 0)
    return a.getbbox()


def redimensionner(image, taille):
    """Réduction sans halo sombre : en alpha prémultiplié."""
    if image.size == taille:
        return image
    pre = image.convert("RGBa").resize(taille, Image.LANCZOS)
    return pre.convert("RGBA")


def echelle_vers(image, cote):
    e = cote / max(image.size)
    return e


def ancres(image):
    """Coins au sol (gauche, avant, droit) et pieds, en pixels de l'image (comme data/atlas.gd)."""
    a = np.asarray(image.getchannel("A")) > 128
    ys, xs = np.nonzero(a)
    if len(xs) == 0:
        return None
    xg, xd = xs.min(), xs.max()
    yg = ys[xs <= xg + 2].max()
    yd = ys[xs >= xd - 2].max()
    yb = ys.max()
    xb = int(xs[ys >= yb - 1].mean())
    xp = int(xs[ys >= yb - max(3, a.shape[0] * 0.06)].mean())
    return {"gauche": [int(xg), int(yg)], "avant": [xb, int(yb)], "droit": [int(xd), int(yd)],
            "pieds": [xp, int(yb)]}


def losange(image):
    """Texture carrée vue de dessus -> dalle isométrique DALLE_LARGEUR x DALLE_HAUTEUR."""
    w, h = image.size
    c = min(w, h)
    carre = image.crop(((w - c) // 2, (h - c) // 2, (w - c) // 2 + c, (h - c) // 2 + c))
    travail = 4 * DALLE_LARGEUR                      # suréchantillonné puis réduit
    cote = round(travail / 2 ** 0.5)
    carre = redimensionner(carre.convert("RGBA"), (cote, cote))
    tourne = carre.rotate(45, resample=Image.BICUBIC, expand=True)
    tourne = tourne.resize((travail, round(travail * ISO_RAPPORT)), Image.BICUBIC)
    # Bord net : masque losange exact (anticrénelé par la réduction)
    tw, th = tourne.size
    masque = Image.new("L", tourne.size, 0)
    ImageDraw.Draw(masque).polygon([(tw / 2, 0), (tw, th / 2), (tw / 2, th), (0, th / 2)], fill=255)
    tourne.putalpha(Image.fromarray(np.minimum(np.asarray(tourne.getchannel("A")), np.asarray(masque))))
    return redimensionner(tourne, (DALLE_LARGEUR, DALLE_HAUTEUR))


def taille_prop(nom):
    """Largeur d'un prop_/base_ : TEXTURE_X x emprise à l'écran. Emprise en cases indiquée par un
    suffixe « _2c » (2 cases de large), 1 case par défaut. Le jeu (Iso.habiller) recale ensuite
    l'image sur l'emprise réelle : ceci fixe seulement une résolution cohérente avec la grille."""
    m = re.search(r"[-_](\d+(?:\.\d+)?)c$", nom.lower())
    cases = float(m.group(1)) if m else 1.0
    return round(cases * LARGEUR_CASE_ECRAN * TEXTURE_X), cases


# --- Traitement ------------------------------------------------------------------------------

def traiter(chemin, args):
    nom = os.path.splitext(os.path.basename(chemin))[0]
    sortie = re.sub(r"[-\s]+", "_", nom.lower())
    res = {"nom": sortie, "source": os.path.relpath(chemin, RACINE), "anomalies": []}
    prefixe, cat = categorie(nom)
    res["categorie"] = cat or "inconnue"
    if cat is None:
        res["anomalies"].append("préfixe inconnu : traitée sans redimensionnement")
    if chemin.lower().endswith((".jpg", ".jpeg")):
        res["anomalies"].append("JPEG (pas PNG) : fond magenta bruité, tolérance appliquée")

    source = Image.open(chemin)
    if source.mode in ("RGBA", "LA", "P") and "A" in source.convert("RGBA").getbands():
        a = np.asarray(source.convert("RGBA").getchannel("A"))
        if a.min() < 255:
            res["anomalies"].append("contient déjà de la transparence (ignorée)")
    p = np.asarray(source.convert("RGB")).astype(float)

    # Dalles et fonds remplissent souvent toute l'image : détourés seulement si bordés de magenta
    fond, couleur, part = examiner_fond(p, args.tolerance)
    plein = cat in ("floor", "bg") and fond != "magenta"
    if fond == "damier" and cat != "floor":
        res["anomalies"].append("FAUX DAMIER de transparence au lieu du magenta : non traitée")
        res["rejet"] = True
        return res, None
    if fond != "magenta" and not plein:
        res["anomalies"].append("fond pas magenta (%.0f %% des bords) : non traitée" % (part * 100))
        res["rejet"] = True
        return res, None

    if plein:
        rgb, alpha = p.copy(), np.ones(p.shape[:2])
    else:
        rgb, alpha = detourer(p, couleur, args.tolerance, args.douceur)
        res["fond"] = [int(round(c)) for c in couleur]
        if np.linalg.norm(couleur - MAGENTA) > args.tolerance:
            res["anomalies"].append("fond magenta délavé %s : détouré sur cette couleur" % res["fond"])
    if cat != "floor" and damier_interieur(p, alpha):
        res["anomalies"].append("FAUX DAMIER dans l'image (derrière le sujet) : à régénérer")
    violet = np.zeros(alpha.shape, bool)
    if not plein and cat != "floor":
        violet = ombres_violettes(p, couleur, rgb, alpha)
        if violet.any():
            res["ombre_violette_px"] = int(violet.sum())
        if cat in ("prop", "map", "wall", "item"):
            teinte = devioler(p, rgb, alpha, violet, effacer=cat == "item")
            if teinte:
                res["teinte_violette_px"] = teinte
        if cat == "prop":
            res["mauve_desature_px"] = desaturer_mauve(rgb, alpha, sombre_seulement=prefixe != "base")
    if not plein:
        res["defrange_px"] = defranger(rgb, alpha)
        res["poussieres_px"] = nettoyer(alpha)
    if cat == "perso" and prefixe != "survivor":     # seuls le héros et les zombies V3 ont une lampe
        retire = retirer_faisceau(rgb, alpha)
        if retire:
            res["faisceau_retire_px"] = retire
            res["anomalies"].append("faisceau de lampe peint, retiré (%d px)" % retire)
    if cat != "floor" and not plein:
        res["traits_fins_px"] = ouvrir(alpha, args.ouverture)
    if cat == "perso":
        tache = taches(alpha, TACHE_PART)
        if tache:
            res["taches_px"] = tache
            res["anomalies"].append("taches détachées du corps effacées (%d px)" % tache)
    if sortie in SOCLE:
        # Le socle montre l'emprise : l'échelle se calcule sur sa largeur, pas sur celle de l'objet
        xs = np.nonzero((alpha > 8 / 255).any(axis=0))[0]
        res["largeur_socle_source"] = int(xs.max() - xs.min() + 1)
        res["socle_px"] = effacer_socle(p, rgb, alpha, violet)
        res["anomalies"].append("socle de dalles effacé (%d px), ombre elliptique ajoutée" % res["socle_px"])

    image = vers_image(rgb, alpha)
    boite = boite_utile(image)
    if boite is None:
        res["anomalies"].append("vide après détourage : non traitée")
        res["rejet"] = True
        return res, None
    w, h = image.size
    if cat not in ("floor", "bg") and (boite[0] <= 1 or boite[1] <= 1 or boite[2] >= w - 1 or boite[3] >= h - 1):
        res["anomalies"].append("touche le bord de l'image : sujet peut-être coupé")
    image = image.crop(boite)
    res["prefixe"] = prefixe
    res["personnage"] = personnage(nom) if cat == "perso" else None
    return res, image


def mettre_a_taille(res, image, echelles_perso, hauteurs):
    cat = res["categorie"]
    if cat == "perso":
        e = echelles_perso[res["personnage"]]
    elif res["nom"] in COTE_NOM:
        e = echelle_vers(image, COTE_NOM[res["nom"]])
    elif cat in COTE:
        e = echelle_vers(image, COTE[cat])
    elif cat == "map":
        e = MAP_LARGEUR / image.width
    elif cat == "wall":
        e = MUR_LARGEUR / image.width
    elif res["nom"] in HAUTEUR_RELATIVE:
        ref, facteur = HAUTEUR_RELATIVE[res["nom"]]
        e = facteur * hauteurs[ref] / image.height
        res["hauteur_relative"] = [ref, facteur]
    elif cat == "prop":
        largeur, cases = taille_prop(res["nom"])
        res["emprise_cases"] = cases
        e = largeur / res.get("largeur_socle_source", image.width)
    elif cat == "bg":
        e = min(1.0, BG_MAX / max(image.size))
    else:
        e = 1.0
    if cat == "floor":
        image = losange(image)
        res["echelle"] = None
    else:
        image = redimensionner(image, (max(1, round(image.width * e)), max(1, round(image.height * e))))
        res["echelle"] = round(e, 4)
    res["taille"] = list(image.size)
    if cat == "floor":
        res["coins_sol"] = {"haut": [DALLE_LARGEUR // 2, 0], "gauche": [0, DALLE_HAUTEUR // 2],
                            "avant": [DALLE_LARGEUR // 2, DALLE_HAUTEUR], "droit": [DALLE_LARGEUR, DALLE_HAUTEUR // 2]}
    elif cat in ("perso", "prop", "wall", "map"):
        a = ancres(image)
        if a:
            res["ancre_pieds"] = a["pieds"]
            if cat in ("prop", "wall"):
                res["coins_sol"] = {k: a[k] for k in ("gauche", "avant", "droit")}
    return image


def empreinte(chemin):
    with open(chemin, "rb") as fh:
        return hashlib.sha1(fh.read()).hexdigest()


def nom_sortie(chemin):
    return re.sub(r"[-\s]+", "_", os.path.splitext(os.path.basename(chemin))[0].lower())


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source", default=os.path.join(RACINE, "docs", "raw", "V3"))
    ap.add_argument("--sortie", default=os.path.join(RACINE, "images", "v3"))
    ap.add_argument("--manifest", default=None, help="défaut : <sortie>/manifest.json")
    ap.add_argument("--tolerance", type=float, default=60, help="distance RGB au magenta = transparent")
    ap.add_argument("--douceur", type=float, default=70, help="largeur de la transition vers l'opaque")
    ap.add_argument("--ouverture", type=int, default=4, help="traits plus fins que 2 x N px effacés (0 = rien)")
    ap.add_argument("--liste", action="store_true", help="montre seulement les nouveautés, sans rien traiter")
    ap.add_argument("--tout", action="store_true", help="retraite toutes les images (et recalcule les échelles)")
    args = ap.parse_args()
    manifest_chemin = args.manifest or os.path.join(args.sortie, "manifest.json")

    manifest = {"images": {}}
    if os.path.exists(manifest_chemin):
        with open(manifest_chemin, encoding="utf-8") as fh:
            manifest = json.load(fh)
    connues = manifest["images"]

    fichiers = sorted(f for f in glob.glob(os.path.join(args.source, "*"))
                      if f.lower().endswith((".png", ".jpg", ".jpeg")))
    if not fichiers:
        print("Aucune image dans", args.source)
        return

    # Nouveautés : image absente du manifest, ou modifiée depuis (empreinte du fichier source)
    a_traiter, a_jour, vus = [], [], {}
    for f in fichiers:
        cle = nom_sortie(f)
        if cle in vus:
            print("  ignorée :", os.path.basename(f), "donnerait le même fichier que", os.path.basename(vus[cle]))
            continue
        vus[cle] = f
        ancienne = connues.get(cle)
        if ancienne is None:
            etat = "nouvelle"
        elif ancienne.get("empreinte") != empreinte(f):
            etat = "modifiée"
        else:
            etat = None
        if etat or args.tout:
            a_traiter.append((f, etat or "retraitée"))
        else:
            a_jour.append(cle)
    disparues = sorted(set(connues) - set(vus))

    print("Déjà traitées, inchangées : %d" % len(a_jour))
    print("À traiter : %d" % len(a_traiter))
    for f, etat in a_traiter:
        print("  %-30s %s" % (os.path.basename(f), etat))
    if disparues:
        print("Dans le manifest mais plus dans la source (gardées) :", ", ".join(disparues))
    if args.liste or not a_traiter:
        return

    resultats = []
    for f, etat in a_traiter:
        print("…", os.path.basename(f), flush=True)
        res, image = traiter(f, args)
        res["empreinte"] = empreinte(f)
        resultats.append((res, image))

    # Échelle commune par personnage : hauteur médiane de ses poses = HAUTEURS[préfixe].
    # Un personnage déjà connu garde son échelle (ses nouvelles poses restent à la même taille).
    echelles = {} if args.tout else dict(manifest.get("echelles_perso", {}))
    hauteurs = {}
    for res, image in resultats:
        if image is not None and res["categorie"] == "perso" and res["personnage"] not in echelles:
            hauteurs.setdefault(res["personnage"], []).append((res["prefixe"], image.height))
    for perso, liste in hauteurs.items():
        echelles[perso] = HAUTEURS[liste[0][0]] / float(np.median([h for _, h in liste]))

    # Hauteurs de référence (HAUTEUR_RELATIVE) : images de ce lot d'abord, sinon le manifest
    hauteurs = {k: v["taille"][1] for k, v in connues.items() if "taille" in v}
    refs = {ref for ref, _ in HAUTEUR_RELATIVE.values()}
    resultats.sort(key=lambda ri: ri[0]["nom"] not in refs)
    os.makedirs(args.sortie, exist_ok=True)
    traitees, anomalies = [], []
    for res, image in resultats:
        if image is not None:
            image = mettre_a_taille(res, image, echelles, hauteurs)
            hauteurs[res["nom"]] = image.height
            fichier = os.path.join(args.sortie, res["nom"] + ".png")
            image.save(fichier, optimize=True)
            res["fichier"] = os.path.relpath(fichier, RACINE)
            traitees.append(res)
        entree = {k: v for k, v in res.items() if v is not None and k not in ("prefixe",)}
        connues[res["nom"]] = entree
        if res["anomalies"]:
            anomalies.append(res)
    manifest["echelles_perso"] = {k: round(v, 6) for k, v in sorted(echelles.items())}
    manifest["reglages"] = {"tolerance": args.tolerance, "douceur": args.douceur, "ouverture": args.ouverture,
                            "hauteurs_perso": HAUTEURS, "dalle": [DALLE_LARGEUR, DALLE_HAUTEUR],
                            "iso_rapport": ISO_RAPPORT, "largeur_case_texture": LARGEUR_CASE_ECRAN * TEXTURE_X}
    with open(manifest_chemin, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=1, sort_keys=True)

    print("\nTraitées (%d) :" % len(traitees))
    for r in traitees:
        print("  %-28s %-6s %4dx%-4d pieds=%s" % (r["nom"] + ".png", r["categorie"], r["taille"][0], r["taille"][1],
                                                 r.get("ancre_pieds", "-")))
    print("\nAnomalies (%d) :" % len(anomalies))
    for r in anomalies:
        print("  %s%s" % (os.path.basename(r["source"]), " [REJETÉE]" if r.get("rejet") else ""))
        for a in r["anomalies"]:
            print("      -", a)
    print("\nManifest :", os.path.relpath(manifest_chemin, RACINE))


if __name__ == "__main__":
    main()
