# Revue du code et du gameplay (octobre 2026)

État relu : `main` au commit `a75a3a4` (après « Écrans V3 »). Lots 1 et 2 terminés, refonte visuelle V2/V3 intégrée.
Tests automatiques relancés dans la session cloud (Godot 4.4.1) : les 19 tests passent en 1280x800 et 800x1280
(sorties conformes aux valeurs « attendu »).
Ce document ne change pas le jeu : il liste ce qui est à corriger et propose la suite (prompts prêts à coller
dans `docs/lot3-prompts.md`).

## 1. Résumé en 5 lignes

1. Le code est propre, cohérent et bien commenté : conventions respectées (signaux vers le haut, réglages centralisés, affichage isométrique séparé de la physique), tests riches.
2. Deux risques réels pour Eliott : le geste « retour » d'Android quitte le jeu en pleine partie (pas de pause), et une sauvegarde écrite directement par-dessus l'ancienne peut tout perdre si l'appli est tuée pendant l'écriture.
3. Le combat ne présente aucun risque en un contre un : frapper dès que la batte est prête bat chaque zombie sans perdre un cœur (mesuré, voir 3.1). Se cacher et fuir deviennent inutiles.
4. La progression s'arrête vite : les 3 constructions et le remède s'obtiennent en 4 à 6 parties, ensuite les objets s'accumulent sans usage. Le bandage ne sert à aucune construction.
5. Les lieux sont identiques à chaque partie : après 2 ou 3 passages, Eliott connaît tout par cœur.

## 2. Revue de code

### 2.1 Points forts
- Architecture claire : `Niveau` commun + lieux en scènes héritées ; `Partie` (état, sauvegarde) séparé de l'affichage ; `Reglages` modifiable dans le jeu (`ParametresJeu`) sans toucher au fichier d'origine.
- Affichage isométrique bien isolé (`Iso`) : la physique et l'IA restent simples en coordonnées monde.
- Performance travaillée et mesurée (sol en blocs, brume en petit, qualité basse automatique).
- Tests de scénario nombreux (19), avec captures ; les cas limites de sauvegarde (reprise v1 à v5) sont couverts.
- Toujours un dessin de secours quand une image manque : le jeu ne casse pas si un fichier disparaît.

### 2.2 Bugs et risques (du plus grave au moins grave)

| # | Où | Problème | Conséquence | Correction proposée |
|---|----|----------|-------------|---------------------|
| B1 | `project.godot` | Aucun traitement du bouton / geste « retour » d'Android (`quit_on_go_back` vaut vrai par défaut dans Godot 4). | Un glissement depuis le bord gauche de l'écran (là où est le joystick) peut fermer le jeu en pleine partie. À vérifier sur la tablette (navigation par gestes ou par boutons). | `application/config/quit_on_go_back=false` + `NOTIFICATION_WM_GO_BACK_REQUEST` : dans un lieu, ouvrir une pause ; ailleurs, écran précédent. |
| B2 | `Partie.sauvegarder`, `ParametresJeu.sauvegarder` | Le fichier est réécrit directement. | Si Android tue l'appli pendant l'écriture : fichier tronqué, JSON illisible, `charger()` ne lit rien et la sauvegarde suivante écrase tout (perte de toute la progression). Rare, mais irréversible. | Écrire dans `sauvegarde.json.tmp`, puis `DirAccess.rename_absolute` vers `sauvegarde.json` ; à la lecture, essayer le `.tmp` si le fichier principal est illisible. |
| B3 | HUD / niveau | Pas de pause ni de moyen de quitter un lieu. | Un appel, un parent qui appelle à table : le héros reste exposé, ou il faut tuer l'appli. | Bouton pause (en haut au centre) : Reprendre / Retour à la base (compté comme une défaite, ou sans perte : à décider). |
| B4 | `Base._ready` | Quand la jauge du remède vient d'être remplie, la Base part vers l'écran « Remède trouvé ! » mais exécute quand même `_preparer_chutes()`, qui marque les nouveaux bâtiments comme vus. | Une tente de rescapé gagnée dans la même partie que la 3e fiole ne tombera jamais du ciel. | `return` juste après `change_scene_to_file.call_deferred(...)`. |
| B5 | `Zombie` (états RETOUR et PATROUILLE) | Pas de détection de blocage (le rescapé en a une, pas le zombie). Sans recherche de chemin, un zombie qui a poursuivi le héros derrière une étagère peut rester coincé contre elle pour toute la partie. | Le lieu se vide de sa menace ; incohérent avec le rescapé. | Même règle que le rescapé : bloqué 1 s en RETOUR -> il adopte sa position actuelle comme nouveau départ (ou réapparaît à son départ hors de la lampe). |
| B6 | `Heros.se_cacher` | Le recul d'un coup reçu juste avant (`_recul`) n'est pas annulé. | Le héros caché glisse d'environ 40 px hors de sa cachette ; en sortant, il réapparaît à côté. Petit, mais visible. | `_recul = Vector2.ZERO` dans `se_cacher()`. |
| B7 | `Reglages.AFFICHER_IPS` | Vaut toujours `true`, alors que CLAUDE.md dit « mettre false pour Eliott ». | Le compteur « 9 ips » est affiché en haut de l'écran de jeu. | `false` dans `data/reglages.gd` (le père peut le rallumer dans Réglages, page 2). |
| B8 | `BoutonTactile` | L'action part à l'appui du doigt, pas au lever. | Sur les écrans de menu (Partir, Construire, Y aller), un doigt posé par erreur déclenche tout de suite, sans possibilité d'annuler en glissant. Correct pour Frapper et Cacher. | Option `au_lever` pour les boutons de menu (Construire, Partir, Retour). |
| B9 | `HUD._dessiner_icones` | Zone de 300 px pour les icônes ramassées, 54 px par icône. | Avec les 6 objets de la maison, la 6e icône dépasse à gauche du cadre. | Pas adaptatif (300 / nombre total) ou deux lignes. |
| B10 | CI (`build.yml`) | Les tests ne tournent pas dans GitHub Actions. | Le père ne peut pas lancer les tests depuis son téléphone : une régression n'est vue que sur la tablette. | Étape `xvfb-run` + `tests/lancer.sh` dans le workflow (avertissement seulement au début, puis bloquant). |

### 2.3 Dette technique (sans urgence)
- `Partie.rescapes` et `Partie.lieux_sauves.size()` disent la même chose (deux sources de vérité).
- Objectifs (`Partie.objectif`) et coûts (`Partie.cout`) sont des `match` codés en dur : ajouter un lieu ou une construction oblige à modifier `Partie` en plus de `Reglages`. Mettre la clé du réglage dans `LIEUX` / `CONSTRUCTIONS`.
- Deux dossiers d'outils : `outils/` (V2, français) et `tools/` (V3, anglais), alors que la convention dit « noms en français ».
- `scripts/sortie.gd` commence par « La sortie du supermarché » : elle sert aussi à la maison.
- `README.md` était vide (corrigé avec cette revue).
- `images/v3/bg_map_alt.png` n'est pas utilisée mais part dans l'APK.
- Les tests laissent des fuites à la sortie (« ObjectDB instances leaked ») : sans effet sur le jeu, mais ce bruit masquerait une vraie fuite.

## 3. Revue du gameplay

### 3.1 Mesures faites pendant la revue
Petit script (non ajouté au dépôt) : le héros reste immobile dans l'allée centrale du supermarché et frappe dès que la batte est prête et le zombie à portée.

| Situation | Résultat |
|-----------|----------|
| Gros zombie seul | battu en 4 coups, 3,4 s, **0 cœur perdu** |
| Maigre seul | battu en 2 coups, 1,6 s, **0 cœur perdu** |
| Coureur seul | battu en 1 coup, 0,9 s, **0 cœur perdu** |
| Gros + maigre de deux côtés | battus en 6 coups, 3,7 s, 1 cœur perdu |

Explication : la batte touche à 90 px, le zombie blesse à 45 px ; chaque coup le repousse (350) et le sonne 0,4 s ; la batte est prête 0,5 s après. Le zombie n'a jamais le temps de revenir au contact.

### 3.2 Ce qui marche bien
- Boucle complète Base -> Carte -> Lieu -> Fin -> Base, sans game over brutal : idéal pour 10 ans.
- Lisibilité : « ! » / « ? », yeux qui brillent, objets qui scintillent, cœurs animés, étoiles de fin.
- Le rescapé donne un vrai objectif secondaire, sans punition.
- Les bâtiments qui tombent du ciel rendent la progression visible et gratifiante.
- Les Réglages dans le jeu laissent Eliott jouer au game designer.

### 3.3 Ce qui freine le fun
1. **Combat sans risque** (mesure 3.1) : frapper en premier gagne toujours. Les cachettes, le bruit et le cône de vue (le cœur du jeu d'infiltration) deviennent facultatifs.
2. **On peut tout fuir** : le héros (260) est plus rapide que tous les zombies (coureur 252 en charge) et la sortie est toujours ouverte. Une partie « courir à la sortie » vaut 1 étoile en 10 secondes.
3. **Menace invisible** : le bruit n'est pas montré, et le cône de vue est quasi invisible dans la nuit (on ne le voit pas sur la capture `capture_b` alors que le zombie poursuit le héros). L'enfant ne comprend pas pourquoi un zombie arrive.
4. **Lieux figés** : objets, zombies et rescapé toujours aux mêmes endroits.
5. **Économie courte** : 3 constructions coûtent en tout 3 conserves, 1 eau, 4 piles (environ 2 parties). Le remède (3 fioles, 2 par tour des lieux) se remplit en 2 ou 3 parties. Ensuite, rien à acheter : l'inventaire monte sans but. Le **bandage ne sert à rien** (aucun coût, pas de soin) sauf l'objectif de la maison.
6. **Objets inutiles dans le lieu** : on n'a jamais de choix à faire (garder ou utiliser).
7. **Après le remède**, rien ne change dans le monde : l'objectif du supermarché reste « 1 fiole », et les fioles suivantes dorment dans l'inventaire.
8. **Les rescapés ne font rien** à la base (la vision dit « rescapés qui travaillent »).

## 4. Incohérences relevées

| Où | Incohérence | Statut |
|----|-------------|--------|
| CLAUDE.md « Version 1 visée » | « 3 types de zombies » : déjà atteint (gros, maigre, coureur). | Corrigé dans CLAUDE.md (état d'avancement ajouté). |
| CLAUDE.md « Sauvegarde » | Le format décrit est la version 3, la version 6 est expliquée par morceaux. | Corrigé : format complet de la version 6. |
| CLAUDE.md, journal « Écran Réglages » | « 26 réglages (5 pages) » ; aujourd'hui 30 réglages, 6 pages (page Rescapé). | Précisé dans le journal. |
| `data/reglages.gd` vs CLAUDE.md | `AFFICHER_IPS = true` alors que la doc demande `false` pour Eliott. | À corriger (B7). |
| Vision vs jeu | « Héros plus rapide qu'eux » mais aussi « attaquer, fuir ou se cacher » : comme la fuite et l'attaque gagnent toujours, se cacher n'a pas de raison d'être. | Proposition L3-b. |
| Nom vs image | Le type `bandage` s'affiche avec l'image d'une trousse de secours (`IMAGES_OBJETS`). | À trancher avec Eliott (renommer en « Trousse » ou garder). |
| Constructions vs objets | Le bandage n'entre dans aucun coût alors que les 4 autres objets servent. | Proposition L3-c. |
| Remède vs objectif | Jauge pleine : le supermarché demande toujours une fiole qui ne sert plus. | Proposition L3-f. |
| Écran Réglages | Il permet un héros à 100 et des zombies à 400 : la règle « héros plus rapide » peut être cassée sans avertissement. | Acceptable (c'est un outil de design), à signaler à Eliott. |
| `outils/` et `tools/` | Deux dossiers pour le même rôle, un nom anglais. | Noté dans CLAUDE.md. |
| `scripts/sortie.gd` | Commentaire « sortie du supermarché » alors qu'elle sert à tous les lieux. | Noté (à corriger au prochain passage dans ce fichier). |
| « Idées lot 2 » | Idées jamais faites (ondes de bruit, cône découpé par les murs), toujours sous le titre du lot 2 terminé. | Déplacées dans « Idées » avec renvoi aux propositions. |

## 5. Propositions (par ordre de priorité)

Chaque ligne tient en une session. Prompts complets dans `docs/lot3-prompts.md`.

| Étape | Contenu | Pourquoi | Effort |
|-------|---------|----------|--------|
| L3-a | Robustesse : pause + retour Android (B1, B3), sauvegarde sûre (B2), B4 à B7, tests dans GitHub Actions (B10). | Protège la progression d'Eliott et le travail du père. | Petit |
| L3-b | Combat avec risque + menace lisible : le gros zombie n'est plus sonné à chaque coup (« garde »), le zombie prévient avant de frapper (bras levés 0,3 s), ondes de bruit visibles, cônes visibles dans la nuit. | Redonne un sens à la fuite et aux cachettes ; l'enfant comprend ce qui se passe. | Moyen |
| L3-c | Objets utiles : 1 bandage peut soigner 1 cœur pendant la mission (bouton cœur du HUD) ; nouvelles constructions qui consomment bandages et eau (infirmerie, jardin déjà dessiné `base_garden`). | Crée des choix (« je soigne ou je garde ? ») et un usage à chaque objet. | Moyen |
| L3-d | Lieux qui changent : chaque objet a 2 ou 3 places possibles tirées à chaque partie ; le rescapé aussi. | Rejouabilité sans nouveau contenu graphique. | Petit |
| L3-e | Étoiles retenues par lieu (meilleur score affiché sur la carte et dans la fiche) + rescapés qui rapportent 1 objet par mission. | Motive à rejouer pour 3 étoiles ; tient la promesse « rescapés qui travaillent ». | Petit |
| L3-f | 3e lieu : la pharmacie (vignette prête), avec une porte fermée à clef (clef V3 prête) ; après le remède, la fiole sert à **guérir** un zombie, qui devient un rescapé. | Nouveau contenu + une fin de boucle positive et pas violente, très adaptée à un enfant. | Gros |

À décider avec Eliott avant L3-b et L3-c (valeurs entre crochets dans les prompts) : difficulté voulue, nombre de soins par mission, coût des nouvelles constructions.

Petites idées (une ligne chacune, à piocher) :
- Vibration courte quand le héros est touché (`Input.vibrate_handheld`, permission VIBRATE à ajouter à l'export ; vérifie que la tablette a un vibreur).
- Sons de ramassage et de porte : à fournir par le père (règle « pas d'assets externes » sauf sons fournis).
- Chronomètre de mission et record par lieu (défi « sortir en moins de 1 min »).
- Zombies qui « reniflent » autour de la cachette où le héros s'est caché sous leurs yeux (tension sans punition : se cacher marche toujours).
