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

Pour chaque image (.png, .jpg) du dossier source (jamais modifié ni supprimé) :
1. contrôle du fond : magenta attendu ; un faux damier de transparence (gris/blanc) est signalé
   et l'image n'est pas traitée ;
2. clé couleur : distance au magenta < tolérance = transparent, puis une zone de transition
   (« douceur ») où l'alpha monte et où la couleur est démélangée du magenta ;
3. défrangeage : sur les 3 px du bord, la teinte magenta restante est retirée (liseré rose,
   surtout dû à la compression JPEG) ; poussières isolées et traits très fins supprimés ;
4. personnages : le faisceau de lampe peint (clair, hors du contour noir) est retiré, le jeu
   dessine le sien ;
5. rognage au contenu, puis taille selon le préfixe du nom (voir CATEGORIES) ;
6. floor_ : texture carrée vue de dessus -> losange isométrique de la taille des dalles du jeu
   (rotation 45°, écrasement vertical à Iso.RAPPORT) ;
7. écriture dans le dossier de sortie (nom en minuscules, « - » -> « _ ») et mise à jour de
   manifest.json (taille, ancre aux pieds, coins au sol, anomalies).
Besoin : Python 3, numpy, pillow.
"""
import argparse
import glob
import hashlib
import json
import os
import re

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

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
}
COTE = {"item": 128, "icon": 192}        # plus grand côté
BG_MAX = 2048

# Mots de pose : ce qui les précède nomme le personnage (Heros-walk-a -> heros, même échelle
# pour toutes ses poses : la hauteur médiane de ses poses vaut HAUTEURS[préfixe]).
POSES = {"idle", "iddle", "walk", "run", "attack", "hit", "hurt", "death", "die", "dead",
         "hide", "back", "front", "side", "a", "b", "c", "d", "1", "2", "3", "4"}


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
    """Regarde une bande de 4 % sur les bords : 'magenta', 'damier' ou 'inconnu'."""
    h, w, _ = p.shape
    m = max(4, int(min(h, w) * 0.04))
    bord = np.concatenate([p[:m].reshape(-1, 3), p[-m:].reshape(-1, 3),
                           p[:, :m].reshape(-1, 3), p[:, -m:].reshape(-1, 3)])
    dm = np.linalg.norm(bord - MAGENTA, axis=-1)
    part_magenta = float((dm < tolerance).mean())
    if part_magenta > 0.6:
        return "magenta", part_magenta
    # Damier : gris neutres clairs, sur deux niveaux, qui alternent
    neutre = (bord.max(-1) - bord.min(-1) < 24) & (bord.mean(-1) > 110)
    if neutre.mean() > 0.6:
        lum = bord[neutre].mean(-1)
        if np.percentile(lum, 90) - np.percentile(lum, 10) > 12:
            return "damier", part_magenta
    return "inconnu", part_magenta


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

def detourer(p, tolerance, douceur):
    """Clé couleur + démélange : renvoie rgb (float) et alpha (0..1)."""
    dm = np.linalg.norm(p - MAGENTA, axis=-1)
    alpha = np.clip((dm - tolerance) / douceur, 0, 1)
    rgb = p.copy()
    partiel = (alpha > 0) & (alpha < 1)
    a = alpha[partiel][:, None]
    rgb[partiel] = np.clip(MAGENTA + (p[partiel] - MAGENTA) / a, 0, 255)
    return rgb, alpha


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
    fond, part = examiner_fond(p, args.tolerance)
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
        rgb, alpha = detourer(p, args.tolerance, args.douceur)
    if cat != "floor" and damier_interieur(p, alpha):
        res["anomalies"].append("FAUX DAMIER dans l'image (derrière le sujet) : à régénérer")
    if not plein:
        res["defrange_px"] = defranger(rgb, alpha)
        res["poussieres_px"] = nettoyer(alpha)
    if cat == "perso":
        retire = retirer_faisceau(rgb, alpha)
        if retire:
            res["faisceau_retire_px"] = retire
            res["anomalies"].append("faisceau de lampe peint, retiré (%d px)" % retire)
    if cat != "floor" and not plein:
        res["traits_fins_px"] = ouvrir(alpha, args.ouverture)

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


def mettre_a_taille(res, image, echelles_perso):
    cat = res["categorie"]
    if cat == "perso":
        e = echelles_perso[res["personnage"]]
    elif cat in COTE:
        e = echelle_vers(image, COTE[cat])
    elif cat == "prop":
        largeur, cases = taille_prop(res["nom"])
        res["emprise_cases"] = cases
        e = largeur / image.width
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
    elif cat in ("perso", "prop"):
        a = ancres(image)
        if a:
            res["ancre_pieds"] = a["pieds"]
            if cat == "prop":
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

    os.makedirs(args.sortie, exist_ok=True)
    traitees, anomalies = [], []
    for res, image in resultats:
        if image is not None:
            image = mettre_a_taille(res, image, echelles)
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
