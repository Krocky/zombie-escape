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

## Lot 1 : périmètre (en cours)
Uniquement l'EXPLORATION d'un supermarché abandonné, jouable du début à la fin :
- Écran titre (Jouer), écran de fin (Victoire / Retour à la base) avec Rejouer.
- Un niveau : murs, 3 cachettes (cartons, congélateur), 4 à 6 objets, une sortie.
- Héros : joystick virtuel à gauche ; à droite boutons Attaquer (corps à corps, délai) et Se cacher (actif près d'une cachette).
- 2 zombies : lent+résistant, rapide+fragile. Patrouille, détection vue (cône) + bruit, poursuite, abandon. Héros plus rapide qu'eux.
- PV du héros, dégâts au contact. Mort => "Retour à la base", perte aléatoire de la moitié des objets. Pas de base : on affiche l'inventaire.
- Ambiance : CanvasModulate sombre, PointLight2D lampe torche, léger brouillard.
- Pas d'assets externes, pas de son.

Étapes : (a) projet + héros au joystick + build, (b) zombie qui poursuit, (c) attaque et PV,
(d) cachettes et détection, (e) objets, sortie, écrans, (f) ambiance lumineuse.

## Direction artistique
- Dark cartoon, aplats vectoriels, contours épais, palette bleu nuit / gris-violet, lampe torche jaune chaud, zombies verts un peu rigolos, pas de gore.
- Référence : `docs/reference/style-b-supermarche.png` (ambiance, palette, persos UNIQUEMENT). Attention : c'est un JPEG malgré l'extension.
- Héros : capuche, sac à dos, batte, lampe torche. Zombie lent : gros. Zombie rapide : maigre.
- Vue 3/4 orthogonale (type Zelda), pas isométrique. Tri de profondeur par Y.
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
- Étape (b) : détection par simple distance (sera remplacée par vue en cône + bruit à l'étape d). Pas de recherche de chemin : le zombie fonce tout droit et glisse le long des obstacles (les étagères aident à le semer).
- Boutons d'action : scène `BoutonTactile` maison (gère plusieurs doigts) ; un `Button` Godot ne réagit qu'au premier doigt, donc pas pendant qu'on tient le joystick.
- Attaque : le héros émet `attaque` ; le niveau touche les zombies à portée, devant le héros (ou au-dessus / en dessous). Le coup repousse et sonne le zombie (étoiles).
- Contact : le zombie émet `touche_heros` ; le niveau appelle `recevoir_degats` sur le héros (recul + clignotement d'invulnérabilité).
- Zombie battu : il bascule et s'efface (pas de gore).
- Étape (c) provisoire : à la mort du héros, le niveau recommence au bout de 2 s (l'écran « Retour à la base » arrive à l'étape e).
- Le niveau transmet la position du héros aux zombies (groupe `zombies`) à chaque frame ; aucun zombie ne connaît le nœud du héros.

## Journal des lots
- Lot 1 / étape (a) : projet Godot, palette, réglages, niveau supermarché (murs, étagères, caisses), héros dessiné qui se déplace au joystick, caméra qui suit, workflow de build APK + release.
- Lot 1 / étape (b) : orientation portrait + paysage ; zombies lent (gros) et rapide (maigre), patrouille, poursuite avec « ! », abandon puis retour au point de départ.
- Lot 1 / étape (c) : bouton Frapper (batte, délai entre deux coups), cœurs du héros, dégâts au contact, recul, zombie sonné puis battu.

## Idées lot 2
- (vide pour l'instant)
