# Zombie Escape

Jeu mobile Android 2D (Godot 4.4, GDScript, rendu Compatibility).
Game designer : Eliott (10 ans). Développeur : son père, uniquement depuis l'appli mobile Claude Code (pas de PC).
Tests sur tablette Xiaomi Pad 5 (16:10) et téléphone Android.

## Le jeu (vision complète, NE PAS tout construire)
Apocalypse zombie, ambiance sombre (nuit, brouillard), pas gore, accessible à un enfant.
Un survivant reconstruit une base, sauve des rescapés et cherche un remède.
Boucle : BASE (construire, rescapés qui travaillent) -> CARTE (choisir un lieu + objectif) -> EXPLORATION (héros sur place : attaquer, fuir ou se cacher).
Échec sans game over brutal : retour à la base en perdant des objets, ou capture puis mission de sauvetage.
Version 1 visée plus tard : 1 héros, 5 à 8 lieux, 3 types de zombies, ~10 armes/objets, ~10 rescapés. Solo, hors ligne.
Hors périmètre définitif : multijoueur, construction libre, monde ouvert, comptes, réseau, pub, achats.

## Lot 1 : périmètre (terminé ; retours de test intégrés)
Uniquement l'EXPLORATION d'un supermarché abandonné, jouable du début à la fin :
- Écran titre (Jouer), écran de fin (Victoire / Retour à la base) avec Rejouer.
- Un niveau : murs, 3 cachettes (cartons, congélateur), 4 à 6 objets, une sortie.
- Héros : joystick virtuel à gauche ; à droite boutons Attaquer (corps à corps, délai) et Se cacher (actif près d'une cachette).
- 2 zombies : lent+résistant, rapide+fragile. Patrouille, détection vue (cône) + bruit, poursuite, abandon. Héros plus rapide qu'eux.
- PV du héros, dégâts au contact. Mort => "Retour à la base", perte aléatoire de la moitié des objets. Pas de base : on affiche l'inventaire.
- Ambiance : CanvasModulate sombre, PointLight2D lampe torche, léger brouillard.
- Pas d'assets externes, pas de son. EXCEPTION décidée par le père avant l'étape f : 5 sons MP3 fournis par lui (`sons/`).

Étapes : (a) projet + héros au joystick + build, (b) zombie qui poursuit, (c) attaque et PV,
(d) cachettes et détection, (e) objets, sortie, écrans, (f) ambiance lumineuse.

## Direction artistique
- Dark cartoon, aplats vectoriels, contours épais, palette bleu nuit / gris-violet, lampe torche jaune chaud, zombies verts un peu rigolos, pas de gore.
- Référence : `docs/reference/original.png` (ex `style-b-supermarche.png` : cible visuelle, ambiance, palette, persos ; c'est un JPEG malgré l'extension). `docs/reference/actuel.png` : rendu avant refonte. `docs/raw/` : images de travail de la discussion « rendu visuel » (voir Méthode de travail).
- Sprites `docs/raw/` (V1, JPEG 512x286) : trop petits. `docs/raw/V2/` : planches 2752x1536 sur fond magenta, isométriques ; certaines contiennent l'image cible incrustée (mélangée au magenta, alignée pixel pour pixel avec `original.png`).
- Héros : capuche, sac à dos, batte, lampe torche. Zombie lent : gros. Zombie rapide : maigre.
- Vue 3/4 orthogonale (type Zelda), pas isométrique. Tri de profondeur par Y. Refonte visuelle : vue 3/4 « dessinée » (décision du père) : seul le dessin change, physique et IA inchangées.
- Lot 1 : formes géométriques dessinées en code (`_draw`), contour épais (`Palette.CONTOUR`, `Dessin.EPAISSEUR`).
- Toutes les couleurs viennent de `data/palette.gd` (autoload `Palette`), extraites de l'image de référence.

## Conventions
- Une scène par entité (`scenes/`), un script par scène (`scripts/`, même nom en snake_case).
- Signaux vers le haut, appels de méthode vers le bas (le parent appelle ses enfants, les enfants émettent des signaux). Pas de références croisées entre frères.
- Équilibrage : TOUTES les valeurs réglables (vitesses, PV, dégâts, portées, délais) dans `data/reglages.gd` (autoload `Reglages`). Eliott modifie ce fichier.
- Origine des entités = au sol (aux pieds), le dessin monte vers les Y négatifs, pour que le tri par Y soit correct.
- Obstacles (`Mur`) : `position` = milieu du bord bas de l'emprise au sol ; `taille` = emprise au sol (collision) ; `hauteur` = face avant dessinée.
- Code et noms en français, sans accents dans les identifiants.
- Fenêtre 1280x720, stretch `canvas_items`, aspect `expand`. Paysage ET portrait (demande du père après l'étape a) : l'autoload `Ecran` passe la base en 720x1280 en portrait. UI ancrée aux bords, boutons tactiles >= 100 px, à vérifier dans les deux sens.
- Contrôles tactiles uniquement (`emulate_touch_from_mouse` activé seulement pour tester à la souris).
- Sauvegarde locale (inventaire) dans `user://`.
- Fichiers `.uid` générés par Godot 4.4 : à committer.

## Lot 2 : proposé (option A : Base + Carte), en attente du choix d'Eliott
Étapes : (a) écran Base + inventaire, (b) 3 constructions (barricade, atelier, lampe renforcée), (c) carte avec 2 lieux,
(d) 2e lieu : la maison, (e) objectifs de mission + jauge du remède.
Prompts complets, un par session : `docs/lot2-prompts.md` (valeurs entre crochets = propositions modifiables par Eliott).
Alternatives écartées pour l'instant : (B) plus de contenu d'exploration (3e zombie, armes, rescapé), (C) personnalisation du héros (prévue au lot 3).

## Méthode de travail
- Le père lance une session Claude Code par étape (prompt de `docs/lot2-prompts.md`), valide sur la tablette, puis lance la suivante.
- Une AUTRE discussion travaille en parallèle sur le rendu visuel (dessins `_draw`, palette, `docs/reference`, `docs/raw`). Toujours `git pull origin main` avant de commencer ; ne pas réécrire le dessin des entités sans nécessité ; en cas de conflit, garder les changements visuels de l'autre discussion.
- Pousser sur main (autorisé par le père) ; si la session impose une branche, pousser aussi sur main en fast-forward.
- Le père ajoute parfois des fichiers directement sur GitHub (images, sons) : chaque ajout déclenche un build/une Release.

## Tests
- `tests/test_*.gd` : scénarios automatiques (SceneTree) qui simulent le toucher et vérifient le comportement ; ils affichent leurs résultats et enregistrent des captures d'écran dans `$CAPTURES`.
- Lancer : `GODOT=<godot 4.4.1> CAPTURES=<dossier> tests/lancer.sh 1280x800` puis `800x1280` (besoin de `xvfb-run` ; le son passe par un pilote factice, donc les sons ne sont pas vraiment testés).
- `test_e` efface la sauvegarde `user://` de l'environnement de test (pas celle de la tablette).
- `tests/` est exclu de l'export APK (`exclude_filter` dans export_presets.cfg).
- Installer Godot dans une session cloud : télécharger `Godot_v4.4.1-stable_linux.x86_64.zip` depuis les releases GitHub de godotengine, dézipper, lancer avec `--headless`.

## Build
- `.github/workflows/build.yml` : à chaque push, export APK debug arm64-v8a avec Godot 4.4.1 (template non-Gradle, min SDK 21, compatible Android 11+).
- Sur `main` uniquement : GitHub Release `build-<numéro>` avec le fichier `.apk`.
- Signature : keystore debug FIXE `android/debug.keystore` (alias `androiddebugkey`, mot de passe `android`). Debug uniquement, aucun secret. Il permet d'installer chaque version par-dessus l'ancienne sans perdre la sauvegarde.
- `version/code` = numéro de build GitHub (injecté par le workflow).
- Validation locale possible dans la session cloud : Godot 4.4.1 headless (`--headless --import`, puis lancement court de la scène).

## Décisions prises (points ambigus -> solution la plus simple)
- Godot 4.4.1 (stable, min SDK 21 avec le template APK standard).
- Joystick « flottant » : toucher n'importe où dans la moitié gauche de l'écran place le joystick sous le doigt. Au repos il s'affiche en bas à gauche.
- Vitesse du héros : pleine vitesse dès que le joystick dépasse la zone morte (plus simple pour un enfant que l'analogique).
- Le dessin des formes communes (polygone + contour) est dans `scripts/dessin.gd` (classe utilitaire `Dessin`, pas une scène).
- Les obstacles (murs, étagères, caisses) partagent une seule scène `Mur` avec un `style`.
- Orientation : capteur libre (portrait + paysage), au lieu du « paysage forcé » du brief initial. Pour revenir au paysage seul : `window/handheld/orientation=4` dans project.godot.
- Zombies : une seule scène `Zombie` avec un `type` (LENT / RAPIDE) et un aller-retour de patrouille (`patrouille`, relatif au départ).
- Pas de recherche de chemin : le zombie fonce tout droit et glisse le long des obstacles (les étagères aident à le semer).
- Boutons d'action : scène `BoutonTactile` maison (gère plusieurs doigts) ; un `Button` Godot ne réagit qu'au premier doigt, donc pas pendant qu'on tient le joystick.
- Attaque : le héros émet `attaque` ; le niveau touche les zombies à portée, devant le héros (ou au-dessus / en dessous). Le coup repousse et sonne le zombie (étoiles).
- Contact : le zombie émet `touche_heros` ; le niveau appelle `recevoir_degats` sur le héros (recul + clignotement d'invulnérabilité).
- Zombie battu : il bascule et s'efface (pas de gore).
- Le niveau transmet la position du héros aux zombies (groupe `zombies`) à chaque frame, avec `detectable` (faux si caché ou K.O.) ; aucun zombie ne connaît le nœud du héros.
- Vue : cône (angle + distance, plus loin en poursuite) et ligne de vue bloquée par le décor (rayon physique, couche 1). Tout près (contact x1,5), il te sent même de dos.
- Cône de vue dessiné au sol (repère pour l'enfant), sans découpe par les murs. Il est sur l'enfant `Cone` (z_index -1) ; `Monde` a z_index 1 pour passer au-dessus du sol.
- Bruit : le héros émet `bruit` (pas toutes les 0,4 s en marchant, coup de batte) ; un zombie qui entend va voir (« ? ») mais ne poursuit que s'il voit.
- États du zombie : PATROUILLE -> POURSUITE (« ! ») -> CHERCHE (« ? », au dernier endroit vu/entendu) -> RETOUR -> PATROUILLE.
- Cachettes : se cacher marche toujours, même sous les yeux d'un zombie (choix « enfant »). Caché : invisible, immobile, silencieux, ne peut pas frapper, pas de dégâts. On sort uniquement avec le bouton (Sortir).
- Objets : ramassés automatiquement en marchant dessus (pas de bouton). 5 objets : conserve, eau, bandage, piles, fiole de remède. Ils ne servent à rien en jeu au lot 1 (pas de soin) : ils vont dans l'inventaire.
- Sortie : toujours ouverte ; l'atteindre = Victoire, avec tous les objets ramassés (pas d'objet obligatoire).
- Mort : on perd la moitié des objets ramassés, au hasard, arrondi en dessous (1 objet -> rien de perdu ; 3 -> 1 perdu).
- Enchaînement : Titre -> Niveau -> Fin (Victoire / Retour à la base) -> Rejouer -> Niveau. L'autoload `Partie` garde le résultat et l'inventaire.
- Sauvegarde : `user://sauvegarde.json` = `{"version": 1, "inventaire": {type: nombre}}`, cumulée sur toutes les parties, affichée sur l'écran de fin.
- Écrans titre/fin : `BoutonTactile` en forme de pilule (si la taille n'est pas carrée).
- Sons (fournis par le père, rangés dans `sons/` car `docs/` est ignoré par Godot) : cri `zombie_gros` / `zombie_maigre` quand un zombie voit le héros (passage en POURSUITE, au plus un cri toutes les `ZOMBIE_DELAI_CRI` s) ; `taper1..3` au hasard quand la batte touche un zombie. Sons spatialisés (AudioStreamPlayer2D, écouteur = caméra). Volume global : `Reglages.SONS_VOLUME`.
- Zombie battu : drapeau `_battu` définitif (il ne bouge plus jamais), invisible jusqu'à la fin du son de coup, puis enlevé. (Bug corrigé : sans ce drapeau, il « renaissait » pendant le son.)
- Nuit : `CanvasModulate` (`Palette.NUIT` x `Reglages.NUIT_CLARTE`) dans le niveau, très sombre (demande d'Eliott : on ne voit les zombies au loin que dans le faisceau) ; le HUD (CanvasLayer 10) n'est pas assombri.
- Sortie : petite lumière verte pour la retrouver dans le noir. Les objets n'ont pas de lumière (à trouver à la lampe).
- Lampe : deux PointLight2D sur le héros, `Halo` (dégradé rond, autour de lui) et `Lampe` (cône dessiné par code dans `_texture_faisceau`, aucune image). Le faisceau suit la dernière direction du joystick (8 directions). Dans une cachette, la lampe s'éteint (le halo reste).
- Brouillard : scène `Brouillard` (z_index 2), nappes de cercles transparents qui dérivent ; épaisseur réglable (`BROUILLARD_OPACITE`).
- Caché : le héros n'est plus rendu invisible (sinon ses lumières s'éteignent) ; il ne se dessine simplement pas.
- Couches physiques : 1 décor (murs, cachettes), 2 héros, 3 zombies (valeur 4).
- Volumes (refonte lot 1) : `Dessin.boite` dessine face avant + côté droit + dessus ; le bord arrière est décalé vers la droite de `profondeur x Dessin.OBLIQUE` (max `OBLIQUE_MAX` = 24 px, pour les murs très profonds). La collision reste l'emprise au sol rectangulaire.
- Ombres : texture dégradée unique (`Dessin.ombre`), sur un enfant `Ombre` en z_index -1 pour les obstacles (sous les personnages), dans le `_draw` pour les personnages.
- Yeux des zombies (refonte lot 2) : dessinés sur l'enfant `Yeux` avec un `CanvasItemMaterial` UNSHADED : ils échappent au `CanvasModulate` et brillent dans le noir (lueur `ZOMBIE_YEUX_LUEUR`). Le corps reste assombri hors de la lampe.
- Faisceau : bord net, cœur plus fort, texture calculée une seule fois (`static var`). Halo réduit. Vignettage : scène `Vignette` (CanvasLayer 5, sous le HUD), une texture dégradée étirée, ne capte pas les doigts.
- Brume : une texture dégradée unique, nappes aplaties au ras du sol, graine fixe ; `BROUILLARD_OPACITE` garde le même sens.
- Lune : une PointLight2D bleue (`Palette.LUNE`) au sol sous chaque fenêtre du mur du fond. Total : 6 lumières (halo, lampe, sortie, 3 lunes).
- `Reglages.AFFICHER_IPS` : compteur d'images par seconde en haut au centre, pour tester la fluidité (mettre false pour Eliott).
- Détails déterministes (produits des étagères, fissures) : hasard à graine = position de l'obstacle. Fenêtres du mur du fond : `Mur.fenetres` (x locaux), placées à l'écart de la porte.

## Journal des lots
- Lot 1 / étape (a) : projet Godot, palette, réglages, niveau supermarché (murs, étagères, caisses), héros dessiné qui se déplace au joystick, caméra qui suit, workflow de build APK + release.
- Lot 1 / étape (b) : orientation portrait + paysage ; zombies lent (gros) et rapide (maigre), patrouille, poursuite avec « ! », abandon puis retour au point de départ.
- Lot 1 / étape (c) : bouton Frapper (batte, délai entre deux coups), cœurs du héros, dégâts au contact, recul, zombie sonné puis battu.
- Lot 1 / étape (d) : 3 cachettes (2 cartons, 1 congélateur) + bouton Cacher/Sortir, vue en cône bloquée par les murs, bruit des pas et des coups, recherche puis retour.
- Lot 1 / étape (e) : 5 objets à ramasser + compteur, sortie, écran titre, écran de fin (Victoire / Retour à la base avec perte de la moitié des objets), Rejouer, sauvegarde de l'inventaire.
- Lot 1 / étape (f) : nuit (CanvasModulate), lampe torche (halo + faisceau qui suit la direction), brouillard, sons des zombies (cri quand ils te voient) et des coups de batte.
- Lot 1 / retours de test : volume -6 dB, nuit beaucoup plus sombre + réglage `NUIT_CLARTE`, lumière verte sur la sortie, correction des zombies qui renaissaient.
- Clôture lot 1 : tests automatiques ajoutés au dépôt (`tests/`), prompts du lot 2 rédigés (`docs/lot2-prompts.md`).

## Refonte visuelle (après le lot 1, demande du père)
Lots : 1 volumes 3/4, 2 éclairage, 3 personnages, 4 décor (sol, débris), 5 objets, 6 retours de jeu, 7 UI.
- Refonte / lot 1 : obstacles et cachettes en volume (dessus, face, côté), étagères garnies, caisses à lattes, carton scotché, congélateur vitré, fenêtres cassées au fond, ombres douces au sol.
- Refonte / lot 2 : faisceau net et chaud, halo réduit, vignettage, brume au ras du sol, lumière de lune sous les fenêtres, yeux des zombies qui brillent dans le noir, compteur d'ips.

## Idées lot 2
- Montrer le bruit à l'écran (petites ondes autour du héros) pour qu'on comprenne pourquoi un zombie arrive.
- Cône de vue découpé par les murs.
- Avec la nuit très sombre, les cônes de vue se voient peu : à surveiller (les garder visibles dans l'ombre si c'est trop dur).
