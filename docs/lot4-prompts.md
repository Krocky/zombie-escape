# Lot 4 : les idées d'Eliott (octobre 2026)

Demandes d'Eliott recueillies le 26 octobre 2026. Un bloc = une nouvelle discussion Claude Code, à envoyer dans l'ordre, après validation de l'étape précédente sur la tablette.
Chaque bloc est complet (règles de session comprises) : il suffit de le copier en entier. Les valeurs entre crochets [ ] sont des propositions : Eliott peut les changer avant d'envoyer le prompt.
Les prompts ont été écrits avant le début du lot : chaque session est priée de suivre le code réel si une étape précédente a fait autrement.

Avancement : [x] L4-a [x] L4-b [x] L4-c [x] L4-d [x] L4-e [x] L4-f [x] L4-g [x] L4-h1 [x] L4-h2 [ ] L4-i

Règle commune : ne jamais casser une sauvegarde existante, ne jamais perdre ce que le joueur a déjà construit.

## Vue d'ensemble

| Étape | Contenu | Dépend de |
|---|---|---|
| L4-a | La base devient un parking où l'on marche (corrige le bug des constructions qui flottent), voiture de survie | |
| L4-b | Placement libre des constructions, barricades multiples | a |
| L4-c | Rescapés qui se promènent et remercient | a |
| L4-d | Sauvegarde multi-parties | |
| L4-e | Deux musiques (base / niveaux) | fichier musique d'Eliott |
| L4-f | Potager : fruit bonus de vitesse | a, d |
| L4-g | Tourelles automatiques et balles | a, b |
| L4-h1 | Niveau 4 : vagues, flèches, rescapés emportés, fin | a, b, c, g |
| L4-h2 | Niveau 4 : barricades qui cassent, ferraille, réparation | h1 |
| L4-i | Niveau 5 : big boss (à préciser avec Eliott) | h2 |

Ordre changé par rapport à la liste d'Eliott : la base explorable passe en premier, parce que le placement libre et le niveau 4 ont besoin d'un vrai sol sur lequel poser les choses. Le niveau 4 est coupé en deux sessions (h1, h2) car il est trop gros pour une seule.

À faire par le père avant certaines étapes :
- Avant L4-d : garder l'APK actuel et, si possible, une copie de la partie d'Eliott (la session crée aussi un fichier de secours).
- Avant L4-e : déposer la musique d'Eliott dans `sons/` sous le nom `musique_niveaux.mp3`.

---

## L4-a : la base devient un parking où l'on marche

```
Tu es mon développeur Godot sur "Zombie Escape". Lis d'abord CLAUDE.md en entier (vision, conventions, décisions, journal) et respecte-le, puis docs/lot4-prompts.md (demandes d'Eliott pour tout le lot 4 ; ne fais QUE l'étape demandée). Les étapes précédentes du lot 4 ont pu prendre des décisions différentes de ce que ce prompt suppose : en cas d'écart, suis le code et CLAUDE.md, et note l'adaptation.
Règles pour cette session :
- Commence par `git pull origin main`. Une autre discussion modifie le rendu visuel en parallèle (dessins, palette, docs/reference, docs/raw) : ne modifie pas le dessin des entités existantes sauf si l'étape l'exige ; en cas de conflit, garde leurs changements visuels.
- Travaille et pousse sur main. Si ta session t'impose une branche, pousse aussi sur main en fast-forward (j'autorise).
- Installe Godot 4.4.1 headless et valide : import sans erreur, `tests/lancer.sh` en 1280x800 et 800x1280 (CLAUDE.md, section Tests), plus le nouveau test demandé. Regarde les captures d'écran.
- Toutes les nouvelles valeurs d'équilibrage dans data/reglages.gd (Eliott les modifie) ; si elles se règlent en jeu, ajoute-les dans ParametresJeu.PAGES.
- Paysage et portrait, boutons tactiles >= 100 px.
- Sauvegarde : une partie existante doit toujours se charger sans rien perdre. Si tu changes de version, reprends l'ancienne comme d'habitude et teste la reprise.
- Commit à chaque étape fonctionnelle, pousse, vérifie que le build GitHub Actions est vert et que la Release build-N est publiée.
- Mets à jour CLAUDE.md (décisions prises, journal des lots, vision et avancée si elles changent) et coche l'étape dans docs/lot4-prompts.md.
- Point ambigu : prends la solution la plus simple, note-la dans CLAUDE.md, continue. Ne pose une question que si tu es bloqué.
- N'ajoute rien hors de l'étape demandée.
- À la fin : résume en 3 lignes ce que je dois tester à la main sur la tablette.

Lot 4, étape (a) : LA BASE DEVIENT UN PARKING OÙ L'ON MARCHE (demande d'Eliott).
Problème signalé par Eliott : dans la base, les constructions et les tentes des rescapés « volent dans les airs » au lieu d'être posées sur le parking.
1. Diagnostic d'abord : sauvegarde de test avec toutes les constructions et 4 tentes, captures de la base actuelle en paysage et en portrait. Trouve la cause (positions `PLACES` sur le fond `bg_base` recadré, chute du ciel, ancrage des images...) et note-la en 2 lignes dans CLAUDE.md.
2. La base n'est plus un écran fixe : c'est une scène où le héros se déplace, avec la même logique que les lieux (vue isométrique, joystick, caméra qui suit, tri en profondeur, collisions). Réutilise la mécanique des lieux plutôt que de la dupliquer.
- Décor : un grand parking [environ 2400x1600 unités monde], sol d'asphalte avec lignes de places, quelques obstacles (voitures abandonnées ou blocs de béton en dessin de secours si aucune image n'existe), bords fermés. Pas besoin de nouvelles images : images existantes si elles conviennent, sinon dessin en code. La place doit permettre plus tard beaucoup de barricades (étape b) et une attaque de zombies (étape h).
- Éclairé : pas de nuit noire, pas besoin de la lampe torche (réglage [BASE_CLARTE]).
- Aucun zombie. HUD de la base : pas de boutons Frapper, Cacher, Soigner, Guérir, ni d'objectif. Garder l'inventaire, la jauge du remède, le tiroir « Construire », les boutons Héros et Réglages.
- Toutes les constructions existantes et les tentes sont posées AU SOL (pieds dans leur emprise), à des emplacements fixes pour l'instant [constructions au centre du camp, tentes groupées dans un coin], avec collision. Le placement libre viendra à l'étape b.
- Une construction faite dans le tiroir apparaît aussitôt à son emplacement. La chute du ciel peut rester, mais elle se termine posée au sol.
- Voiture de survie garée dans le parking : quand le héros est à côté, un bouton « Start » (>= 100 px) apparaît ; il ouvre la Carte. Il remplace le bouton « Partir ». Au retour de mission, le héros réapparaît près de la voiture.
- L'écran « Remède trouvé ! », les gains du jardin, de l'infirmerie et des rescapés au retour fonctionnent comme avant. Retour Android dans la base : comme avant.
- Adapte les tests qui passent par la base (ceux qui appuient sur « Partir » passent maintenant par la voiture).
- Nouveau test test_aa : déplacement du héros dans la base, aucun zombie, chaque construction et chaque tente a ses pieds au sol dans le parking, voiture -> Start -> Carte, sauvegarde version 7 reprise sans perte.
Hors étape (ne pas faire) : placement libre et nouvelles barricades (b), rescapés qui se promènent (c), sauvegarde multi-parties (d).
```

---

## L4-b : placement libre et barricades

```
Tu es mon développeur Godot sur "Zombie Escape". Lis d'abord CLAUDE.md en entier (vision, conventions, décisions, journal) et respecte-le, puis docs/lot4-prompts.md (demandes d'Eliott pour tout le lot 4 ; ne fais QUE l'étape demandée). Les étapes précédentes du lot 4 ont pu prendre des décisions différentes de ce que ce prompt suppose : en cas d'écart, suis le code et CLAUDE.md, et note l'adaptation.
Règles pour cette session :
- Commence par `git pull origin main`. Une autre discussion modifie le rendu visuel en parallèle (dessins, palette, docs/reference, docs/raw) : ne modifie pas le dessin des entités existantes sauf si l'étape l'exige ; en cas de conflit, garde leurs changements visuels.
- Travaille et pousse sur main. Si ta session t'impose une branche, pousse aussi sur main en fast-forward (j'autorise).
- Installe Godot 4.4.1 headless et valide : import sans erreur, `tests/lancer.sh` en 1280x800 et 800x1280 (CLAUDE.md, section Tests), plus le nouveau test demandé. Regarde les captures d'écran.
- Toutes les nouvelles valeurs d'équilibrage dans data/reglages.gd (Eliott les modifie) ; si elles se règlent en jeu, ajoute-les dans ParametresJeu.PAGES.
- Paysage et portrait, boutons tactiles >= 100 px.
- Sauvegarde : une partie existante doit toujours se charger sans rien perdre. Si tu changes de version, reprends l'ancienne comme d'habitude et teste la reprise.
- Commit à chaque étape fonctionnelle, pousse, vérifie que le build GitHub Actions est vert et que la Release build-N est publiée.
- Mets à jour CLAUDE.md (décisions prises, journal des lots, vision et avancée si elles changent) et coche l'étape dans docs/lot4-prompts.md.
- Point ambigu : prends la solution la plus simple, note-la dans CLAUDE.md, continue. Ne pose une question que si tu es bloqué.
- N'ajoute rien hors de l'étape demandée.
- À la fin : résume en 3 lignes ce que je dois tester à la main sur la tablette.

Lot 4, étape (b) : PLACEMENT LIBRE DES CONSTRUCTIONS et BARRICADES (demande d'Eliott). Prérequis : étape a faite (la base est un parking où l'on marche).
- Vision : CLAUDE.md classe « construction libre » en hors périmètre définitif. Eliott la demande : retire-la de cette liste et note la décision (placement libre dans la base seulement, pas de construction pièce par pièce).
- Mode placement : après « Construire » sur une carte du tiroir, le tiroir se ferme et un fantôme de la construction apparaît [devant le héros]. Toucher le sol du parking déplace le fantôme à cet endroit (au lever du doigt, comme la carte, pour ne pas confondre avec un glissement). Fantôme vert = emplacement libre, rouge = refusé (chevauche une construction, une tente, un obstacle, la voiture, le héros, ou sort du parking). Boutons « Poser » et « Annuler » (>= 100 px). Les objets ne sont retirés de l'inventaire qu'au moment de « Poser ». La chute du ciel joue à l'endroit posé.
- Le héros ne doit jamais être enfermé : refuse aussi un emplacement qui couperait tout chemin entre le héros et la voiture (vérification simple sur une grille grossière du parking).
- Les constructions déjà faites restent là où l'étape a les a mises (elles deviennent leur position sauvegardée).
- Barricades : la barricade se construit plusieurs fois, [jusqu'à 20], au coût `BARRICADE_COUT` à chaque fois. Seule la première donne l'effet actuel (+cœurs) ; les suivantes servent à bloquer les zombies au niveau 4 (étape h). Elles ont une collision. Carte du tiroir : « Construire » reste actif tant qu'on n'a pas atteint le maximum, avec le nombre déjà construit (« x3 »). Les autres constructions restent uniques.
- Sauvegarde : chaque construction posée garde sa position (et l'ordre de pose). Nouvelle version, reprise de la 7 (positions de l'étape a).
- Nouveau test test_ab : fantôme vert / rouge, Poser retire les objets et sauvegarde la position, Annuler ne retire rien, emplacement qui enferme le héros refusé, 3 barricades posées puis rechargées aux mêmes positions, une sauvegarde version 7 reprise.
Hors étape : déplacer ou démolir une construction déjà posée, rescapés qui se promènent (c), tourelles (g).
```

---

## L4-c : rescapés qui se promènent et remercient

```
Tu es mon développeur Godot sur "Zombie Escape". Lis d'abord CLAUDE.md en entier (vision, conventions, décisions, journal) et respecte-le, puis docs/lot4-prompts.md (demandes d'Eliott pour tout le lot 4 ; ne fais QUE l'étape demandée). Les étapes précédentes du lot 4 ont pu prendre des décisions différentes de ce que ce prompt suppose : en cas d'écart, suis le code et CLAUDE.md, et note l'adaptation.
Règles pour cette session :
- Commence par `git pull origin main`. Une autre discussion modifie le rendu visuel en parallèle (dessins, palette, docs/reference, docs/raw) : ne modifie pas le dessin des entités existantes sauf si l'étape l'exige ; en cas de conflit, garde leurs changements visuels.
- Travaille et pousse sur main. Si ta session t'impose une branche, pousse aussi sur main en fast-forward (j'autorise).
- Installe Godot 4.4.1 headless et valide : import sans erreur, `tests/lancer.sh` en 1280x800 et 800x1280 (CLAUDE.md, section Tests), plus le nouveau test demandé. Regarde les captures d'écran.
- Toutes les nouvelles valeurs d'équilibrage dans data/reglages.gd (Eliott les modifie) ; si elles se règlent en jeu, ajoute-les dans ParametresJeu.PAGES.
- Paysage et portrait, boutons tactiles >= 100 px.
- Sauvegarde : une partie existante doit toujours se charger sans rien perdre. Si tu changes de version, reprends l'ancienne comme d'habitude et teste la reprise.
- Commit à chaque étape fonctionnelle, pousse, vérifie que le build GitHub Actions est vert et que la Release build-N est publiée.
- Mets à jour CLAUDE.md (décisions prises, journal des lots, vision et avancée si elles changent) et coche l'étape dans docs/lot4-prompts.md.
- Point ambigu : prends la solution la plus simple, note-la dans CLAUDE.md, continue. Ne pose une question que si tu es bloqué.
- N'ajoute rien hors de l'étape demandée.
- À la fin : résume en 3 lignes ce que je dois tester à la main sur la tablette.

Lot 4, étape (c) : RESCAPÉS VIVANTS DANS LA BASE (demande d'Eliott). Prérequis : étape a faite.
- Chaque rescapé sauvé (y compris les zombies guéris) est un personnage dans la base, avec sa tente. Lève la limite actuelle de 4 tentes : [une tente par rescapé, au plus 10], dans le coin des tentes de l'étape a.
- Ils se promènent : ils marchent lentement [RESCAPE_BASE_VITESSE] vers un point au hasard du parking (sans traverser les obstacles ni les constructions), s'arrêtent [2 à 5 s], repartent. Ils ne bloquent pas le héros. Réutilise la scène `Rescape` avec un nouvel état si c'est simple, sinon une scène à part ; même images (`survivor_follow` en marche, `survivor_happy` à l'arrêt).
- Quand le héros passe près d'un rescapé [moins de 120], le rescapé s'arrête, se tourne vers lui et affiche une bulle qui le remercie de l'avoir sauvé (phrases tirées au hasard parmi [« Merci de m'avoir sauvé ! », « Sans toi, j'étais fichu ! », « Merci <prénom du héros> ! »]), pendant [2,5 s], puis au plus une fois toutes les [20 s] pour ce rescapé.
- Prépare l'étape h : une méthode qui envoie un rescapé devant sa tente et l'y garde (pas encore utilisée en jeu, mais testée).
- Les rescapés de la base ne changent rien aux gains (objets rapportés à chaque retour) : la logique de `Partie` reste la même.
- Nouveau test test_ac : 3 rescapés dans la base se déplacent, n'entrent pas dans les obstacles, la bulle apparaît quand le héros approche et ne revient pas avant le délai, la méthode « devant sa tente » les y amène.
Hors étape : sauvegarde multi-parties (d), niveau 4 (h).
```

---

## L4-d : sauvegarde multi-parties

```
Tu es mon développeur Godot sur "Zombie Escape". Lis d'abord CLAUDE.md en entier (vision, conventions, décisions, journal) et respecte-le, puis docs/lot4-prompts.md (demandes d'Eliott pour tout le lot 4 ; ne fais QUE l'étape demandée). Les étapes précédentes du lot 4 ont pu prendre des décisions différentes de ce que ce prompt suppose : en cas d'écart, suis le code et CLAUDE.md, et note l'adaptation.
Règles pour cette session :
- Commence par `git pull origin main`. Une autre discussion modifie le rendu visuel en parallèle (dessins, palette, docs/reference, docs/raw) : ne modifie pas le dessin des entités existantes sauf si l'étape l'exige ; en cas de conflit, garde leurs changements visuels.
- Travaille et pousse sur main. Si ta session t'impose une branche, pousse aussi sur main en fast-forward (j'autorise).
- Installe Godot 4.4.1 headless et valide : import sans erreur, `tests/lancer.sh` en 1280x800 et 800x1280 (CLAUDE.md, section Tests), plus le nouveau test demandé. Regarde les captures d'écran.
- Toutes les nouvelles valeurs d'équilibrage dans data/reglages.gd (Eliott les modifie) ; si elles se règlent en jeu, ajoute-les dans ParametresJeu.PAGES.
- Paysage et portrait, boutons tactiles >= 100 px.
- Sauvegarde : une partie existante doit toujours se charger sans rien perdre. Si tu changes de version, reprends l'ancienne comme d'habitude et teste la reprise.
- Commit à chaque étape fonctionnelle, pousse, vérifie que le build GitHub Actions est vert et que la Release build-N est publiée.
- Mets à jour CLAUDE.md (décisions prises, journal des lots, vision et avancée si elles changent) et coche l'étape dans docs/lot4-prompts.md.
- Point ambigu : prends la solution la plus simple, note-la dans CLAUDE.md, continue. Ne pose une question que si tu es bloqué.
- N'ajoute rien hors de l'étape demandée.
- À la fin : résume en 3 lignes ce que je dois tester à la main sur la tablette.

Lot 4, étape (d) : PLUSIEURS PARTIES SAUVEGARDÉES (demande d'Eliott).
- AVANT TOUT CHANGEMENT : copie l'actuel `user://sauvegarde.json` en `user://sauvegarde_avant_lot4d.json` au premier lancement de la nouvelle version (une seule fois, jamais écrasée). C'est la partie d'Eliott.
- Plusieurs parties, chacune avec un nom donné par le joueur. Fichiers : un par partie [dans `user://parties/`] + un index (liste, nom, date de dernière sauvegarde, partie en cours), écrits avec `Fichier` (.tmp puis renommage). Les réglages (`user://reglages.json`) restent communs à toutes les parties.
- Migration : la sauvegarde existante devient la première partie, nommée [« Partie de <prénom> »], et c'est la partie en cours. Aucune perte.
- Sauvegarde automatique : comme aujourd'hui à chaque événement, plus [toutes les 60 s] dans la base et quand l'application passe en arrière-plan ou se ferme.
- Bouton « Partie » en haut de la base (>= 100 px, placé sans gêner inventaire, jauge et tiroir, paysage et portrait) qui ouvre un petit menu : « Sauvegarder » (sauvegarde tout de suite et affiche « Partie sauvegardée ! » 1,5 s), « Nouvelle partie », « Mes parties », « Fermer ».
- « Nouvelle partie » : demande le nom (champ en haut de l'écran pour rester visible au-dessus du clavier, comme le choix du héros), puis « Êtes-vous sûr ? » (Oui / Non). Oui : sauvegarde la partie en cours, crée la nouvelle (vide), en fait la partie en cours, puis écran de choix du héros.
- « Mes parties » (aussi depuis l'écran titre, bouton à côté de « Jouer ») : liste avec nom, prénom du héros, nombre de rescapés, date ; toucher une partie la charge (après avoir sauvegardé celle en cours) ; bouton « Effacer » par partie avec « Effacer <nom> ? » (Oui / Non). Choix : on ne peut pas effacer la partie en cours (bouton grisé), il faut d'abord en charger une autre. Liste défilable au doigt si elle dépasse.
- « Jouer » sur le titre reprend la partie en cours.
- Retour Android dans ces écrans : écran précédent sans rien changer.
- Tests : la fonction d'effacement des tests ne doit effacer que l'environnement de test. Adapte les tests qui effacent `user://sauvegarde.json`.
- Nouveau test test_ad : migration d'une version 7 en première partie (fichier de secours créé une seule fois), création d'une 2e partie, bascule entre les deux sans mélange (inventaires différents), effacement d'une partie, impossible d'effacer la partie en cours, sauvegarde forcée par le bouton.
Hors étape : sauvegarde dans le cloud, export de partie.
```

---

## L4-e : deux musiques

```
Tu es mon développeur Godot sur "Zombie Escape". Lis d'abord CLAUDE.md en entier (vision, conventions, décisions, journal) et respecte-le, puis docs/lot4-prompts.md (demandes d'Eliott pour tout le lot 4 ; ne fais QUE l'étape demandée). Les étapes précédentes du lot 4 ont pu prendre des décisions différentes de ce que ce prompt suppose : en cas d'écart, suis le code et CLAUDE.md, et note l'adaptation.
Règles pour cette session :
- Commence par `git pull origin main`. Une autre discussion modifie le rendu visuel en parallèle (dessins, palette, docs/reference, docs/raw) : ne modifie pas le dessin des entités existantes sauf si l'étape l'exige ; en cas de conflit, garde leurs changements visuels.
- Travaille et pousse sur main. Si ta session t'impose une branche, pousse aussi sur main en fast-forward (j'autorise).
- Installe Godot 4.4.1 headless et valide : import sans erreur, `tests/lancer.sh` en 1280x800 et 800x1280 (CLAUDE.md, section Tests), plus le nouveau test demandé. Regarde les captures d'écran.
- Toutes les nouvelles valeurs d'équilibrage dans data/reglages.gd (Eliott les modifie) ; si elles se règlent en jeu, ajoute-les dans ParametresJeu.PAGES.
- Paysage et portrait, boutons tactiles >= 100 px.
- Sauvegarde : une partie existante doit toujours se charger sans rien perdre. Si tu changes de version, reprends l'ancienne comme d'habitude et teste la reprise.
- Commit à chaque étape fonctionnelle, pousse, vérifie que le build GitHub Actions est vert et que la Release build-N est publiée.
- Mets à jour CLAUDE.md (décisions prises, journal des lots, vision et avancée si elles changent) et coche l'étape dans docs/lot4-prompts.md.
- Point ambigu : prends la solution la plus simple, note-la dans CLAUDE.md, continue. Ne pose une question que si tu es bloqué.
- N'ajoute rien hors de l'étape demandée.
- À la fin : résume en 3 lignes ce que je dois tester à la main sur la tablette.

Lot 4, étape (e) : DEUX MUSIQUES (demande d'Eliott).
Prérequis : Eliott a généré une nouvelle musique ; je l'ai déposée dans `sons/` sous le nom [`musique_niveaux.mp3`] (sans espaces). Si le fichier n'y est pas, arrête-toi et dis-le-moi, ne fais rien d'autre.
- L'autoload `Musique` gère deux pistes : la musique actuelle (`sons/musique.mp3`) pour la base, le titre, la carte, les réglages, le choix du héros, les écrans de fin et de parties ; la nouvelle pour les lieux (supermarché, maison, pharmacie, et plus tard le niveau 4).
- Changement de piste en fondu enchaîné [1 s] ; pas de coupure ni de redémarrage quand on passe d'un écran à un autre qui garde la même piste. Boucle activée sur la nouvelle piste (dans le .import et dans le code, comme l'autre).
- Volume : même réglage `MUSIQUE_VOLUME` pour les deux ; si la nouvelle est nettement plus forte ou plus faible à l'oreille des valeurs mesurées (niveau moyen), ajoute un réglage d'équilibrage [MUSIQUE_NIVEAUX_ECART en dB].
- En pause dans un lieu, la musique des niveaux continue (comme aujourd'hui).
- Nouveau test test_ae : piste de la base sur la base et la carte, piste des niveaux dans un lieu, retour à la piste de la base sur l'écran de fin, pas de redémarrage entre base et carte (position de lecture qui continue).
Hors étape : sons nouveaux, musique par lieu.
```

---

## L4-f : potager et fruit bonus

```
Tu es mon développeur Godot sur "Zombie Escape". Lis d'abord CLAUDE.md en entier (vision, conventions, décisions, journal) et respecte-le, puis docs/lot4-prompts.md (demandes d'Eliott pour tout le lot 4 ; ne fais QUE l'étape demandée). Les étapes précédentes du lot 4 ont pu prendre des décisions différentes de ce que ce prompt suppose : en cas d'écart, suis le code et CLAUDE.md, et note l'adaptation.
Règles pour cette session :
- Commence par `git pull origin main`. Une autre discussion modifie le rendu visuel en parallèle (dessins, palette, docs/reference, docs/raw) : ne modifie pas le dessin des entités existantes sauf si l'étape l'exige ; en cas de conflit, garde leurs changements visuels.
- Travaille et pousse sur main. Si ta session t'impose une branche, pousse aussi sur main en fast-forward (j'autorise).
- Installe Godot 4.4.1 headless et valide : import sans erreur, `tests/lancer.sh` en 1280x800 et 800x1280 (CLAUDE.md, section Tests), plus le nouveau test demandé. Regarde les captures d'écran.
- Toutes les nouvelles valeurs d'équilibrage dans data/reglages.gd (Eliott les modifie) ; si elles se règlent en jeu, ajoute-les dans ParametresJeu.PAGES.
- Paysage et portrait, boutons tactiles >= 100 px.
- Sauvegarde : une partie existante doit toujours se charger sans rien perdre. Si tu changes de version, reprends l'ancienne comme d'habitude et teste la reprise.
- Commit à chaque étape fonctionnelle, pousse, vérifie que le build GitHub Actions est vert et que la Release build-N est publiée.
- Mets à jour CLAUDE.md (décisions prises, journal des lots, vision et avancée si elles changent) et coche l'étape dans docs/lot4-prompts.md.
- Point ambigu : prends la solution la plus simple, note-la dans CLAUDE.md, continue. Ne pose une question que si tu es bloqué.
- N'ajoute rien hors de l'étape demandée.
- À la fin : résume en 3 lignes ce que je dois tester à la main sur la tablette.

Lot 4, étape (f) : LE FRUIT DU POTAGER (demande d'Eliott). Prérequis : étapes a et d faites.
- Le potager = le jardin existant (lot 3 c, `base_garden`). Il garde son don de conserves à chaque retour. En plus, une fois construit, il fait pousser un fruit.
- Un fruit est prêt [3 h] (`FRUIT_DELAI`, en secondes dans `Reglages` pour que les tests puissent le raccourcir) après la dernière cueillette, en temps réel, même quand le jeu est fermé : enregistre l'heure de cueillette (heure système en secondes) dans la partie. Un seul fruit à la fois, pas de cumul. Si l'heure de la tablette recule (heure actuelle avant la dernière cueillette), remets la cueillette à maintenant (pas de fruit bloqué). Le premier fruit est prêt dès que le jardin est construit.
- Fruit prêt : dessiné sur le potager (dessin en code, [pomme rouge brillante] avec un petit scintillement, pas besoin d'image). Le héros le cueille en marchant dessus (comme un objet) : gerbe d'étoiles, petit texte « Fruit cueilli : plus rapide au prochain niveau ! ».
- Pas prêt : quand le héros est près du potager, petit texte « Prochain fruit dans 2 h 14 » (heures et minutes).
- Effet : le fruit cueilli est gardé dans la partie (un seul en réserve) et sert au prochain lieu : à l'arrivée, le héros court [x1,5] (`FRUIT_VITESSE`) pendant [10 s] (`FRUIT_DUREE`), avec une icône de fruit et le temps restant dans le HUD. Il est consommé à l'arrivée, même en cas de défaite ensuite.
- Les trois réglages dans `Reglages` ; `FRUIT_VITESSE` et `FRUIT_DUREE` aussi dans l'écran Réglages (page « Héros et batte »).
- Sauvegarde : nouvelle version (heure de cueillette, fruit en réserve), reprise de l'ancienne.
- Nouveau test test_af : fruit prêt dès la construction du jardin, cueillette, pas de 2e fruit avant le délai, fruit après le délai (délai raccourci), heure qui recule, bonus de vitesse appliqué au lieu suivant puis fini après la durée.
Hors étape : autres fruits ou légumes, autres bonus.
```

---

## L4-g : tourelles automatiques

```
Tu es mon développeur Godot sur "Zombie Escape". Lis d'abord CLAUDE.md en entier (vision, conventions, décisions, journal) et respecte-le, puis docs/lot4-prompts.md (demandes d'Eliott pour tout le lot 4 ; ne fais QUE l'étape demandée). Les étapes précédentes du lot 4 ont pu prendre des décisions différentes de ce que ce prompt suppose : en cas d'écart, suis le code et CLAUDE.md, et note l'adaptation.
Règles pour cette session :
- Commence par `git pull origin main`. Une autre discussion modifie le rendu visuel en parallèle (dessins, palette, docs/reference, docs/raw) : ne modifie pas le dessin des entités existantes sauf si l'étape l'exige ; en cas de conflit, garde leurs changements visuels.
- Travaille et pousse sur main. Si ta session t'impose une branche, pousse aussi sur main en fast-forward (j'autorise).
- Installe Godot 4.4.1 headless et valide : import sans erreur, `tests/lancer.sh` en 1280x800 et 800x1280 (CLAUDE.md, section Tests), plus le nouveau test demandé. Regarde les captures d'écran.
- Toutes les nouvelles valeurs d'équilibrage dans data/reglages.gd (Eliott les modifie) ; si elles se règlent en jeu, ajoute-les dans ParametresJeu.PAGES.
- Paysage et portrait, boutons tactiles >= 100 px.
- Sauvegarde : une partie existante doit toujours se charger sans rien perdre. Si tu changes de version, reprends l'ancienne comme d'habitude et teste la reprise.
- Commit à chaque étape fonctionnelle, pousse, vérifie que le build GitHub Actions est vert et que la Release build-N est publiée.
- Mets à jour CLAUDE.md (décisions prises, journal des lots, vision et avancée si elles changent) et coche l'étape dans docs/lot4-prompts.md.
- Point ambigu : prends la solution la plus simple, note-la dans CLAUDE.md, continue. Ne pose une question que si tu es bloqué.
- N'ajoute rien hors de l'étape demandée.
- À la fin : résume en 3 lignes ce que je dois tester à la main sur la tablette.

Lot 4, étape (g) : TOURELLES AUTOMATIQUES (demande d'Eliott). Prérequis : étapes a et b faites (placement libre).
- Nouvelle construction « Tourelle » : coût [`TOURELLE_COUT` = 3 piles + 1 conserve], [4 au maximum] (`TOURELLE_MAX`), posée librement comme les barricades de l'étape b. Carte du tiroir avec le nombre (« x2 »).
- Nouvel objet « balles » (boîte de balles de tourelle) : type d'inventaire à part entière (inventaire de la base, écran de fin), mais jamais dans les coûts des autres constructions, les bonus de mission ni les trouvailles des rescapés. Une boîte = [`BALLES_PAR_BOITE` = 10] balles. À placer dans les lieux : [1 boîte par lieu], avec 2 ou 3 places tirées au hasard comme les autres objets (lot 3 d). Les boîtes ne comptent pas dans les objectifs.
- Inventaire : il passe à 6 types (et 7 à l'étape h avec la ferraille) : le cadre de l'inventaire de la base, l'écran de fin et le HUD doivent les afficher sans déborder en paysage et en portrait. Profites-en pour corriger B9 (6e icône qui dépasse dans la maison).
- Recharger : dans la base, quand le héros est près d'une tourelle, un bouton « Recharger » (>= 100 px) apparaît s'il a des boîtes ; il verse toutes les balles possibles jusqu'à [`TOURELLE_CAPACITE` = 30]. Nombre de balles affiché au-dessus de chaque tourelle (gris à 0).
- Tir : une tourelle chargée vise le zombie le plus proche à moins de [`TOURELLE_PORTEE` = 400], tourne vers lui, tire toutes les [`TOURELLE_CADENCE` = 0,6 s] : 1 balle consommée, [`TOURELLE_DEGATS` = 1] dégât, petit éclair et trace jusqu'à la cible (dessin en code, pas de gore). Elle ne tire que s'il y a des zombies (donc pas dans la base normale : ce sera au niveau 4).
- Dessin : sans image, dessin en code [trépied + boîtier + canon] dans le style du jeu (contour épais). Note dans CLAUDE.md le nom d'image V3 attendu [`base_turret`] pour que je la génère plus tard.
- Sauvegarde : nouvelle version (balles de chaque tourelle), reprise de l'ancienne.
- Nouveau test test_ag : construction et maximum de 4, boîte ramassée dans un lieu puis dans l'inventaire, recharge (plafond de capacité), tir sur un zombie ajouté dans la base par le test seulement (balles consommées, dégâts, arrêt à 0 balle), pas de tir sans zombie.
Hors étape : niveau 4 (h), autres armes.
```

---

## L4-h1 : niveau 4, l'attaque de la base

```
Tu es mon développeur Godot sur "Zombie Escape". Lis d'abord CLAUDE.md en entier (vision, conventions, décisions, journal) et respecte-le, puis docs/lot4-prompts.md (demandes d'Eliott pour tout le lot 4 ; ne fais QUE l'étape demandée). Les étapes précédentes du lot 4 ont pu prendre des décisions différentes de ce que ce prompt suppose : en cas d'écart, suis le code et CLAUDE.md, et note l'adaptation.
Règles pour cette session :
- Commence par `git pull origin main`. Une autre discussion modifie le rendu visuel en parallèle (dessins, palette, docs/reference, docs/raw) : ne modifie pas le dessin des entités existantes sauf si l'étape l'exige ; en cas de conflit, garde leurs changements visuels.
- Travaille et pousse sur main. Si ta session t'impose une branche, pousse aussi sur main en fast-forward (j'autorise).
- Installe Godot 4.4.1 headless et valide : import sans erreur, `tests/lancer.sh` en 1280x800 et 800x1280 (CLAUDE.md, section Tests), plus le nouveau test demandé. Regarde les captures d'écran.
- Toutes les nouvelles valeurs d'équilibrage dans data/reglages.gd (Eliott les modifie) ; si elles se règlent en jeu, ajoute-les dans ParametresJeu.PAGES.
- Paysage et portrait, boutons tactiles >= 100 px.
- Sauvegarde : une partie existante doit toujours se charger sans rien perdre. Si tu changes de version, reprends l'ancienne comme d'habitude et teste la reprise.
- Commit à chaque étape fonctionnelle, pousse, vérifie que le build GitHub Actions est vert et que la Release build-N est publiée.
- Mets à jour CLAUDE.md (décisions prises, journal des lots, vision et avancée si elles changent) et coche l'étape dans docs/lot4-prompts.md.
- Point ambigu : prends la solution la plus simple, note-la dans CLAUDE.md, continue. Ne pose une question que si tu es bloqué.
- N'ajoute rien hors de l'étape demandée.
- À la fin : résume en 3 lignes ce que je dois tester à la main sur la tablette.

Lot 4, étape (h1) : NIVEAU 4, DÉFENSE DE LA BASE, première partie (demande d'Eliott). Prérequis : étapes a, b, c, g faites.
- Nouveau lieu sur la carte : « Défense de la base » (vignette `map_base` ou dessin en code, dans `Partie.LIEUX`), disponible [dès qu'au moins 1 rescapé est à la base], sinon « Bientôt » avec la phrase « Sauve d'abord un rescapé ». Fiche de la carte : objectif « tuer tous les zombies », nombre de vagues, rescapés à protéger.
- Le niveau se joue sur le parking de la base, la nuit (ambiance des lieux, lampe torche du héros), avec les constructions du joueur à leurs positions sauvegardées, les tourelles avec leurs balles, et les rescapés DEVANT LEUR TENTE (méthode de l'étape c) pendant toute l'attaque. Le héros part près de la voiture. Utilise la logique commune des lieux (HUD, cœurs, Frapper, Soigner, Guérir, pause) ; pas de bouton Cacher (pas de cachette).
- Vagues : [3 vagues de 4, 6 et 8 zombies] (`DEFENSE_VAGUES`), types tirés au hasard parmi gros, maigre, coureur, qui arrivent de [4 entrées] au bord du parking tirées au hasard pour chaque zombie, [un zombie toutes les 1,5 s] dans une vague, [8 s] de pause entre deux vagues avec « Vague 2 / 3 » en grand au centre et dans le HUD.
- Comportement en défense : un zombie avance vers le rescapé le plus proche ; s'il voit le héros, il le poursuit comme d'habitude, puis revient vers les rescapés quand il le perd. Pas de recherche de chemin (comme ailleurs). Les tourelles chargées tirent (étape g).
- Flèches : au-dessus du héros, une flèche par zombie hors de l'écran, qui pointe vers lui (couleur selon le type, un peu transparente plus il est loin).
- Rescapé attrapé : contact d'un zombie avec un rescapé = il est emporté (animation courte, pas de gore : il disparaît dans un nuage), le niveau continue. Après la partie, il n'est plus à la base : son lieu d'origine redevient « rescapé à sauver » (retiré de `lieux_sauves`, `rescapes` diminué) ; un zombie guéri emporté est simplement perdu. Ligne de l'écran de fin : « <n> rescapé(s) emporté(s) : va les rechercher ! ».
- Fin : victoire quand toutes les vagues sont tuées. Défaite si le héros n'a plus de cœurs (on peut recommencer). Étoiles du lieu : 1 = victoire, +1 aucun rescapé emporté (« Défense parfaite ! »), +1 aucun cœur perdu. Victoire : [2 objets bonus] comme une mission réussie ; défaite : pas de perte d'objets (rien n'a été ramassé). Gains du jardin et des rescapés comme après une mission.
- Barricades : cette étape les traite comme des obstacles fixes (elles bloquent). Leur casse et leur réparation sont pour l'étape h2.
- Réglages : nombres des vagues, délais, entrées dans `Reglages` ; [délai entre deux zombies et pause entre vagues] aussi dans l'écran Réglages (nouvelle page « Défense »).
- Nouveau test test_ah : lieu verrouillé sans rescapé, puis disponible ; 3 vagues dans l'ordre ; flèches présentes pour un zombie hors écran ; rescapé emporté retiré de la base et lieu à refaire ; victoire et étoiles ; défaite du héros.
Hors étape : barricades cassables, ferraille et réparation (h2), boss (i).
```

---

## L4-h2 : barricades cassables et ferraille

```
Tu es mon développeur Godot sur "Zombie Escape". Lis d'abord CLAUDE.md en entier (vision, conventions, décisions, journal) et respecte-le, puis docs/lot4-prompts.md (demandes d'Eliott pour tout le lot 4 ; ne fais QUE l'étape demandée). Les étapes précédentes du lot 4 ont pu prendre des décisions différentes de ce que ce prompt suppose : en cas d'écart, suis le code et CLAUDE.md, et note l'adaptation.
Règles pour cette session :
- Commence par `git pull origin main`. Une autre discussion modifie le rendu visuel en parallèle (dessins, palette, docs/reference, docs/raw) : ne modifie pas le dessin des entités existantes sauf si l'étape l'exige ; en cas de conflit, garde leurs changements visuels.
- Travaille et pousse sur main. Si ta session t'impose une branche, pousse aussi sur main en fast-forward (j'autorise).
- Installe Godot 4.4.1 headless et valide : import sans erreur, `tests/lancer.sh` en 1280x800 et 800x1280 (CLAUDE.md, section Tests), plus le nouveau test demandé. Regarde les captures d'écran.
- Toutes les nouvelles valeurs d'équilibrage dans data/reglages.gd (Eliott les modifie) ; si elles se règlent en jeu, ajoute-les dans ParametresJeu.PAGES.
- Paysage et portrait, boutons tactiles >= 100 px.
- Sauvegarde : une partie existante doit toujours se charger sans rien perdre. Si tu changes de version, reprends l'ancienne comme d'habitude et teste la reprise.
- Commit à chaque étape fonctionnelle, pousse, vérifie que le build GitHub Actions est vert et que la Release build-N est publiée.
- Mets à jour CLAUDE.md (décisions prises, journal des lots, vision et avancée si elles changent) et coche l'étape dans docs/lot4-prompts.md.
- Point ambigu : prends la solution la plus simple, note-la dans CLAUDE.md, continue. Ne pose une question que si tu es bloqué.
- N'ajoute rien hors de l'étape demandée.
- À la fin : résume en 3 lignes ce que je dois tester à la main sur la tablette.

Lot 4, étape (h2) : NIVEAU 4, BARRICADES QUI CASSENT et FERRAILLE (demande d'Eliott). Prérequis : étape h1 faite.
- Pendant la défense, chaque barricade a [`BARRICADE_PV` = 6] points de solidité. Un zombie bloqué contre une barricade (il n'avance plus et elle est devant lui) la frappe toutes les [`ZOMBIE_DELAI_CASSE` = 1 s] avec le geste de coup existant : -1 point, éclats de bois, la barricade s'abîme visiblement (fissures dessinées par-dessus, de plus en plus). À 0, elle s'effondre (nuage de poussière) et ne bloque plus.
- Barre de solidité au-dessus de chaque barricade abîmée.
- Choix pour Eliott (à appliquer) : après le niveau, victoire ou défaite, les barricades sont remises en état gratuitement dans la base [on ne les perd pas].
- Nouvel objet « ferraille » : type d'inventaire à part entière (7e type, l'inventaire doit déjà tenir d'après l'étape g), à trouver dans les lieux [1 ou 2 par lieu, avec places tirées au hasard], hors coûts des autres constructions, bonus de mission et trouvailles des rescapés ; ne compte pas dans les objectifs.
- Réparer : pendant la défense, quand le héros est près d'une barricade abîmée (pas effondrée) et a de la ferraille, un bouton « Réparer » (>= 100 px, icône clé à molette dessinée en code) apparaît. Tant qu'il est tenu, la barricade regagne 1 point toutes les [`REPARATION_DELAI` = 0,5 s], chaque point coûte [1] ferraille ; petit à petit, jamais d'un coup. Le héros ne bouge pas pendant qu'il répare (relâcher pour fuir). Une barricade effondrée ne se répare pas pendant le niveau.
- Réglages `BARRICADE_PV`, `ZOMBIE_DELAI_CASSE`, `REPARATION_DELAI` aussi dans la page « Défense » de l'écran Réglages.
- Nouveau test test_ai : zombie bloqué qui casse une barricade jusqu'à l'effondrement puis passe ; réparation qui consomme la ferraille point par point et s'arrête au relâchement ou sans ferraille ; barricades remises en état après le niveau ; ferraille ramassée dans un lieu.
Hors étape : boss (i), nouvelles constructions.
```

---

## L4-i : niveau 5, big boss (pas encore de prompt)

À préciser avec Eliott avant d'écrire le prompt. Questions à lui poser :
- Où se passe le combat : un nouveau lieu, ou la base comme le niveau 4 ?
- À quoi ressemble le boss : un zombie géant, un chef des zombies, autre chose ?
- Comment on le bat : à la batte, avec les tourelles, avec le remède ?
- Est-ce qu'il a des attaques spéciales (charge, appeler d'autres zombies, lancer des choses) ?
- Qu'est-ce qu'on gagne quand on le bat ?
