# Lot 3 : prompts prêts à copier-coller

Propositions issues de `docs/revue.md`. Un bloc = une nouvelle discussion Claude Code, à envoyer dans l'ordre, après validation de l'étape précédente sur la tablette.
Chaque bloc est complet (règles de session comprises) : il suffit de le copier en entier.
Les valeurs entre crochets [ ] sont des propositions : Eliott peut les changer avant d'envoyer le prompt.

Avancement : [x] L3-a [x] L3-b [x] L3-c [x] L3-d [x] L3-e [x] L3-f1 [ ] L3-f2

---

## L3-a : robustesse (pause, retour Android, sauvegarde sûre)

```
Tu es mon développeur Godot sur "Zombie Escape". Lis d'abord CLAUDE.md en entier (vision, conventions, décisions, journal) et respecte-le, puis docs/revue.md (bugs B1 à B10, mesures, propositions).
Règles pour cette session :
- Commence par `git pull origin main`. Une autre discussion modifie le rendu visuel en parallèle (dessins, palette, docs/reference, docs/raw) : ne modifie pas le dessin des entités existantes sauf si l'étape l'exige ; en cas de conflit, garde leurs changements visuels.
- Travaille et pousse sur main. Si ta session t'impose une branche, pousse aussi sur main en fast-forward (j'autorise).
- Installe Godot 4.4.1 headless et valide : import sans erreur, `tests/lancer.sh` en 1280x800 et 800x1280 (CLAUDE.md, section Tests), plus le nouveau test demandé. Regarde les captures d'écran.
- Toutes les nouvelles valeurs d'équilibrage dans data/reglages.gd (Eliott les modifie) ; si elles se règlent en jeu, ajoute-les dans ParametresJeu.PAGES.
- Paysage et portrait, boutons tactiles >= 100 px.
- Commit à chaque étape fonctionnelle, pousse, vérifie que le build GitHub Actions est vert et que la Release build-N est publiée.
- Mets à jour CLAUDE.md (décisions prises, journal des lots, retire de « Problèmes connus » ce qui est corrigé) et coche l'étape dans docs/lot3-prompts.md.
- Point ambigu : prends la solution la plus simple, note-la dans CLAUDE.md, continue. Ne pose une question que si tu es bloqué.
- N'ajoute rien hors de l'étape demandée.
- À la fin : résume en 3 lignes ce que je dois tester à la main sur la tablette.

Lot 3, étape (a) : ROBUSTESSE (docs/revue.md, section 2.2).
- Geste / bouton « retour » d'Android : il ne doit plus quitter le jeu (application/config/quit_on_go_back=false). Dans un lieu : il ouvre la pause. Sur la carte, la base, les réglages, le choix du héros : écran précédent. Sur le titre : rien.
- Bouton Pause dans le HUD (rond >= 100 px, [en haut au centre, sous l'objectif]) : jeu figé (zombies, héros, sons), fond assombri, boutons « Reprendre » et « Retour à la base ». Retour à la base pendant une mission = [défaite normale : moitié des objets perdus].
- Sauvegardes (Partie et ParametresJeu) : écrire dans un fichier .tmp puis le renommer ; à la lecture, reprendre le .tmp si le fichier principal est illisible.
- Corriger B4 (chutes de la base perdues quand l'écran « Remède trouvé ! » s'ouvre), B5 (zombie bloqué en RETOUR ou PATROUILLE : au bout de [1 s] sans avancer, il prend sa place actuelle comme nouveau départ), B6 (recul annulé en se cachant), B7 (AFFICHER_IPS = false).
- GitHub Actions : lancer tests/lancer.sh en 1280x800 dans le workflow, après l'export ; un test qui affiche « ECHEC » ou une erreur de script fait échouer le build.
- Nouveau test test_t : pause, retour, sauvegarde reprise depuis le .tmp.
```

---

## L3-b : un combat qui fait peur, une menace qu'on comprend

```
Tu es mon développeur Godot sur "Zombie Escape". Lis d'abord CLAUDE.md en entier (vision, conventions, décisions, journal) et respecte-le, puis docs/revue.md (bugs B1 à B10, mesures, propositions).
Règles pour cette session :
- Commence par `git pull origin main`. Une autre discussion modifie le rendu visuel en parallèle (dessins, palette, docs/reference, docs/raw) : ne modifie pas le dessin des entités existantes sauf si l'étape l'exige ; en cas de conflit, garde leurs changements visuels.
- Travaille et pousse sur main. Si ta session t'impose une branche, pousse aussi sur main en fast-forward (j'autorise).
- Installe Godot 4.4.1 headless et valide : import sans erreur, `tests/lancer.sh` en 1280x800 et 800x1280 (CLAUDE.md, section Tests), plus le nouveau test demandé. Regarde les captures d'écran.
- Toutes les nouvelles valeurs d'équilibrage dans data/reglages.gd (Eliott les modifie) ; si elles se règlent en jeu, ajoute-les dans ParametresJeu.PAGES.
- Paysage et portrait, boutons tactiles >= 100 px.
- Commit à chaque étape fonctionnelle, pousse, vérifie que le build GitHub Actions est vert et que la Release build-N est publiée.
- Mets à jour CLAUDE.md (décisions prises, journal des lots, retire de « Problèmes connus » ce qui est corrigé) et coche l'étape dans docs/lot3-prompts.md.
- Point ambigu : prends la solution la plus simple, note-la dans CLAUDE.md, continue. Ne pose une question que si tu es bloqué.
- N'ajoute rien hors de l'étape demandée.
- À la fin : résume en 3 lignes ce que je dois tester à la main sur la tablette.

Lot 3, étape (b) : COMBAT et LISIBILITÉ. Aujourd'hui, frapper dès que la batte est prête bat n'importe quel zombie seul sans perdre de cœur (docs/revue.md, 3.1). Fuir et se cacher doivent redevenir utiles, sans rendre le jeu dur pour un enfant.
- Le gros zombie a une « garde » : il n'est sonné et repoussé qu'[un coup sur deux] (les autres coups font des dégâts avec un flash, sans l'arrêter).
- Avant de frapper, un zombie lève les bras [0,3 s] (pose ou dessin qui le montre) : on peut esquiver en reculant. Le coup part seulement à la fin de ce geste, s'il est encore au contact.
- Ondes de bruit visibles : un cercle clair qui s'agrandit jusqu'à la portée du bruit (pas et coups de batte), sur un calque sans ombre, discret pour les pas, plus fort pour la batte.
- Cônes de vue visibles dans la nuit : contour du cône sur un calque non assombri (jaune pâle en patrouille, rouge en poursuite), remplissage léger.
- Nouvelles valeurs aussi dans la page Zombies de l'écran Réglages.
- Refais la mesure de la revue : héros immobile qui frappe dès que possible contre chaque zombie seul ; attendu [au moins 1 cœur perdu contre le gros], 0 contre le coureur.
- Nouveau test test_u : garde du gros, préparation du coup, esquive possible, ondes émises.
```

---

## L3-c : des objets qui servent

```
Tu es mon développeur Godot sur "Zombie Escape". Lis d'abord CLAUDE.md en entier (vision, conventions, décisions, journal) et respecte-le, puis docs/revue.md (bugs B1 à B10, mesures, propositions).
Règles pour cette session :
- Commence par `git pull origin main`. Une autre discussion modifie le rendu visuel en parallèle (dessins, palette, docs/reference, docs/raw) : ne modifie pas le dessin des entités existantes sauf si l'étape l'exige ; en cas de conflit, garde leurs changements visuels.
- Travaille et pousse sur main. Si ta session t'impose une branche, pousse aussi sur main en fast-forward (j'autorise).
- Installe Godot 4.4.1 headless et valide : import sans erreur, `tests/lancer.sh` en 1280x800 et 800x1280 (CLAUDE.md, section Tests), plus le nouveau test demandé. Regarde les captures d'écran.
- Toutes les nouvelles valeurs d'équilibrage dans data/reglages.gd (Eliott les modifie) ; si elles se règlent en jeu, ajoute-les dans ParametresJeu.PAGES.
- Paysage et portrait, boutons tactiles >= 100 px.
- Commit à chaque étape fonctionnelle, pousse, vérifie que le build GitHub Actions est vert et que la Release build-N est publiée.
- Mets à jour CLAUDE.md (décisions prises, journal des lots, retire de « Problèmes connus » ce qui est corrigé) et coche l'étape dans docs/lot3-prompts.md.
- Point ambigu : prends la solution la plus simple, note-la dans CLAUDE.md, continue. Ne pose une question que si tu es bloqué.
- N'ajoute rien hors de l'étape demandée.
- À la fin : résume en 3 lignes ce que je dois tester à la main sur la tablette.

Lot 3, étape (c) : OBJETS UTILES et nouvelles constructions.
- Soin pendant la mission : bouton rond « Soigner » (icône cœur + bandage) dans le HUD, actif seulement si le héros est blessé et a ramassé un bandage dans cette mission. Un appui : +[1] cœur, le bandage est consommé (il ne compte plus dans les objets rapportés ni dans l'objectif). [1] soin par mission au plus.
- 2 nouvelles constructions (même système de cartes que les 3 existantes, dans le tiroir) :
  - [Infirmerie] : coûte [3 bandages] -> on commence chaque mission avec [1 bandage] de soin.
  - [Jardin] (image base_garden et place PLACES.jardin déjà prêtes dans base.gd) : coûte [2 eau + 1 conserve] -> [1 conserve] offerte à chaque retour de mission.
- Le tiroir de la base doit garder ses 5 cartes lisibles en paysage et en portrait.
- Nouveau test test_v : soin, consommation du bandage, les 2 constructions.
```

---

## L3-d : des lieux qui changent à chaque partie

```
Tu es mon développeur Godot sur "Zombie Escape". Lis d'abord CLAUDE.md en entier (vision, conventions, décisions, journal) et respecte-le, puis docs/revue.md (bugs B1 à B10, mesures, propositions).
Règles pour cette session :
- Commence par `git pull origin main`. Une autre discussion modifie le rendu visuel en parallèle (dessins, palette, docs/reference, docs/raw) : ne modifie pas le dessin des entités existantes sauf si l'étape l'exige ; en cas de conflit, garde leurs changements visuels.
- Travaille et pousse sur main. Si ta session t'impose une branche, pousse aussi sur main en fast-forward (j'autorise).
- Installe Godot 4.4.1 headless et valide : import sans erreur, `tests/lancer.sh` en 1280x800 et 800x1280 (CLAUDE.md, section Tests), plus le nouveau test demandé. Regarde les captures d'écran.
- Toutes les nouvelles valeurs d'équilibrage dans data/reglages.gd (Eliott les modifie) ; si elles se règlent en jeu, ajoute-les dans ParametresJeu.PAGES.
- Paysage et portrait, boutons tactiles >= 100 px.
- Commit à chaque étape fonctionnelle, pousse, vérifie que le build GitHub Actions est vert et que la Release build-N est publiée.
- Mets à jour CLAUDE.md (décisions prises, journal des lots, retire de « Problèmes connus » ce qui est corrigé) et coche l'étape dans docs/lot3-prompts.md.
- Point ambigu : prends la solution la plus simple, note-la dans CLAUDE.md, continue. Ne pose une question que si tu es bloqué.
- N'ajoute rien hors de l'étape demandée.
- À la fin : résume en 3 lignes ce que je dois tester à la main sur la tablette.

Lot 3, étape (d) : VARIÉTÉ. Les objets et le rescapé sont toujours aux mêmes endroits ; une partie ne doit pas ressembler à la précédente.
- Chaque objet d'un lieu a [2 ou 3] places possibles (marqueurs dans la scène du lieu, en coordonnées monde, hors des obstacles) ; une place est tirée au hasard à chaque partie.
- Même chose pour le rescapé ([2] cachettes possibles par lieu) et pour la patrouille de [1] zombie par lieu.
- Le sol, les murs et la sortie ne bougent pas. La fiche de la carte (Partie.infos_lieu) doit toujours compter les bons objets.
- Nouveau test test_w : deux parties de suite, au moins un objet a changé de place, jamais dans un obstacle.
```

---

## L3-e : étoiles retenues et rescapés qui travaillent

```
Tu es mon développeur Godot sur "Zombie Escape". Lis d'abord CLAUDE.md en entier (vision, conventions, décisions, journal) et respecte-le, puis docs/revue.md (bugs B1 à B10, mesures, propositions).
Règles pour cette session :
- Commence par `git pull origin main`. Une autre discussion modifie le rendu visuel en parallèle (dessins, palette, docs/reference, docs/raw) : ne modifie pas le dessin des entités existantes sauf si l'étape l'exige ; en cas de conflit, garde leurs changements visuels.
- Travaille et pousse sur main. Si ta session t'impose une branche, pousse aussi sur main en fast-forward (j'autorise).
- Installe Godot 4.4.1 headless et valide : import sans erreur, `tests/lancer.sh` en 1280x800 et 800x1280 (CLAUDE.md, section Tests), plus le nouveau test demandé. Regarde les captures d'écran.
- Toutes les nouvelles valeurs d'équilibrage dans data/reglages.gd (Eliott les modifie) ; si elles se règlent en jeu, ajoute-les dans ParametresJeu.PAGES.
- Paysage et portrait, boutons tactiles >= 100 px.
- Commit à chaque étape fonctionnelle, pousse, vérifie que le build GitHub Actions est vert et que la Release build-N est publiée.
- Mets à jour CLAUDE.md (décisions prises, journal des lots, retire de « Problèmes connus » ce qui est corrigé) et coche l'étape dans docs/lot3-prompts.md.
- Point ambigu : prends la solution la plus simple, note-la dans CLAUDE.md, continue. Ne pose une question que si tu es bloqué.
- N'ajoute rien hors de l'étape demandée.
- À la fin : résume en 3 lignes ce que je dois tester à la main sur la tablette.

Lot 3, étape (e) : MOTIVATION.
- Meilleur nombre d'étoiles retenu par lieu (sauvegarde version 7, reprise d'une version 6 sans étoiles) : affiché sous la vignette du lieu sur la carte et dans sa fiche (3 étoiles icon_star, grises si pas encore gagnées).
- Rescapés au travail : chaque rescapé sauvé rapporte [1] objet au hasard (jamais de fiole) à chaque retour à la base. L'écran de fin l'annonce (« Tes rescapés ont trouvé : ... ») et l'objet rejoint l'inventaire.
- Nouveau test test_x : étoiles gardées (le meilleur score seulement), reprise v6, objets des rescapés.
```

---

## L3-f1 : la pharmacie et sa porte à clef

```
Tu es mon développeur Godot sur "Zombie Escape". Lis d'abord CLAUDE.md en entier (vision, conventions, décisions, journal) et respecte-le, puis docs/revue.md (bugs B1 à B10, mesures, propositions).
Règles pour cette session :
- Commence par `git pull origin main`. Une autre discussion modifie le rendu visuel en parallèle (dessins, palette, docs/reference, docs/raw) : ne modifie pas le dessin des entités existantes sauf si l'étape l'exige ; en cas de conflit, garde leurs changements visuels.
- Travaille et pousse sur main. Si ta session t'impose une branche, pousse aussi sur main en fast-forward (j'autorise).
- Installe Godot 4.4.1 headless et valide : import sans erreur, `tests/lancer.sh` en 1280x800 et 800x1280 (CLAUDE.md, section Tests), plus le nouveau test demandé. Regarde les captures d'écran.
- Toutes les nouvelles valeurs d'équilibrage dans data/reglages.gd (Eliott les modifie) ; si elles se règlent en jeu, ajoute-les dans ParametresJeu.PAGES.
- Paysage et portrait, boutons tactiles >= 100 px.
- Commit à chaque étape fonctionnelle, pousse, vérifie que le build GitHub Actions est vert et que la Release build-N est publiée.
- Mets à jour CLAUDE.md (décisions prises, journal des lots, retire de « Problèmes connus » ce qui est corrigé) et coche l'étape dans docs/lot3-prompts.md.
- Point ambigu : prends la solution la plus simple, note-la dans CLAUDE.md, continue. Ne pose une question que si tu es bloqué.
- N'ajoute rien hors de l'étape demandée.
- À la fin : résume en 3 lignes ce que je dois tester à la main sur la tablette.

Lot 3, étape (f1) : 3e LIEU, la PHARMACIE.
- La pharmacie devient jouable (vignette map_pharmacy déjà prête ; Partie.LIEUX a déjà son entrée) : [1 grande salle + 1 réserve], [1 gros, 1 maigre, 1 coureur], [5] objets, 3 cachettes, un rescapé. Objectif : [rapporter 2 piles].
- La réserve est fermée par une porte à clef : la clef (type clef, déjà préparé, voir CLAUDE.md « Clef ») est dans la salle ; la porte s'ouvre quand le héros arrive devant avec la clef. Attention : la clef ne doit compter ni dans « Objets à trouver » ni dans le compteur du HUD, ni être rapportée à la base.
- Réutilise les scènes existantes (Mur, Cachette, Objet, Zombie, Sortie, Rescape) ; décor en images V3 existantes si possible, sinon dessin de secours ; pas de nouvelle image obligatoire.
- Nouveau test test_y : pharmacie disponible sur la carte, porte fermée sans clef, ouverte avec, clef hors compteur.
```

---

## L3-f2 : le remède qui guérit les zombies

```
Tu es mon développeur Godot sur "Zombie Escape". Lis d'abord CLAUDE.md en entier (vision, conventions, décisions, journal) et respecte-le, puis docs/revue.md (bugs B1 à B10, mesures, propositions).
Règles pour cette session :
- Commence par `git pull origin main`. Une autre discussion modifie le rendu visuel en parallèle (dessins, palette, docs/reference, docs/raw) : ne modifie pas le dessin des entités existantes sauf si l'étape l'exige ; en cas de conflit, garde leurs changements visuels.
- Travaille et pousse sur main. Si ta session t'impose une branche, pousse aussi sur main en fast-forward (j'autorise).
- Installe Godot 4.4.1 headless et valide : import sans erreur, `tests/lancer.sh` en 1280x800 et 800x1280 (CLAUDE.md, section Tests), plus le nouveau test demandé. Regarde les captures d'écran.
- Toutes les nouvelles valeurs d'équilibrage dans data/reglages.gd (Eliott les modifie) ; si elles se règlent en jeu, ajoute-les dans ParametresJeu.PAGES.
- Paysage et portrait, boutons tactiles >= 100 px.
- Commit à chaque étape fonctionnelle, pousse, vérifie que le build GitHub Actions est vert et que la Release build-N est publiée.
- Mets à jour CLAUDE.md (décisions prises, journal des lots, retire de « Problèmes connus » ce qui est corrigé) et coche l'étape dans docs/lot3-prompts.md.
- Point ambigu : prends la solution la plus simple, note-la dans CLAUDE.md, continue. Ne pose une question que si tu es bloqué.
- N'ajoute rien hors de l'étape demandée.
- À la fin : résume en 3 lignes ce que je dois tester à la main sur la tablette.

Lot 3, étape (f2) : SUITE DU REMÈDE. Aujourd'hui, une fois la jauge pleine, rien ne change et les fioles ne servent plus.
- Après le remède (jauge pleine) : une fiole ramassée dans la mission peut être lancée sur un zombie proche (bouton « Guérir », rond >= 100 px, actif seulement près d'un zombie et avec une fiole) ; le zombie s'assoit, redevient humain et compte comme un rescapé sauvé (une tente de plus à la base).
- Pas de gore : nuage vert clair, le zombie redevient une silhouette de survivant [image survivor_happy].
- Une fiole lancée est consommée (elle n'est pas rapportée).
- L'objectif du supermarché après le remède devient [guérir 1 zombie] (fiche de la carte, HUD, écran de fin).
- Nouveau test test_z : bouton inactif avant le remède, guérison après, rescapé compté, objectif rempli.
```
