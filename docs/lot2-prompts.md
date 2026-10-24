# Lot 2 : prompts des étapes (option A : Base + Carte)

Un prompt = une session Claude Code. Les lancer dans l'ordre, après validation de l'étape précédente sur la tablette.
Les valeurs entre crochets [ ] sont des propositions : Eliott peut les changer avant de lancer le prompt.

---

## Prompt commun (à coller au début de chaque étape)

```
Tu es mon développeur Godot sur "Zombie Escape". Lis d'abord CLAUDE.md en entier : il contient la vision, les conventions, les décisions et le journal. Respecte-le.
Règles pour cette session :
- Commence par `git pull origin main`. Une autre discussion modifie le rendu visuel en parallèle (dessins, palette, docs/reference, docs/raw) : ne modifie pas le dessin des entités existantes sauf si l'étape l'exige ; en cas de conflit, garde leurs changements visuels.
- Travaille et pousse sur main. Si ta session t'impose une branche, pousse aussi sur main en fast-forward (j'autorise).
- Installe Godot 4.4.1 headless dans ton environnement et valide : import sans erreur, `tests/lancer.sh` en 1280x800 et 800x1280 (voir CLAUDE.md, section Tests), plus un nouveau test pour cette étape dans tests/. Regarde les captures d'écran.
- Commit à chaque étape fonctionnelle, pousse, vérifie que le build GitHub Actions est vert et que la Release build-N est publiée.
- Mets à jour CLAUDE.md (décisions prises, journal des lots).
- Point ambigu : prends la solution la plus simple, note-la dans CLAUDE.md, continue. Ne pose une question que si tu es bloqué.
- N'ajoute rien hors de l'étape demandée.
- À la fin : résume en 3 lignes ce que je dois tester à la main sur la tablette.
```

---

## Étape L2-a : l'écran Base

```
Lot 2, étape (a) : l'écran BASE.
- Nouvel enchaînement : Titre -> Base -> (bouton "Partir") -> Supermarché -> écran de fin -> (bouton "Retour à la base") -> Base. Le bouton Rejouer de l'écran de fin est remplacé par "Retour à la base".
- La Base est un écran (pas un niveau jouable) : un abri dessiné en formes simples dans le style du jeu (feu de camp, tente ou abri en planches, nuit), l'inventaire affiché avec une icône par type d'objet et son nombre.
- Réutilise le dessin des objets pour les icônes (factorise-le si besoin, sans changer leur apparence).
- Sauvegarde : passe le fichier en version 2 (prévois la place pour les constructions de l'étape b), avec reprise automatique d'une sauvegarde version 1 sans perte de l'inventaire.
- Paysage et portrait, boutons tactiles >= 100 px.
```

## Étape L2-b : les constructions de la base

```
Lot 2, étape (b) : CONSTRUIRE à la base avec les objets rapportés.
- 3 constructions, chacune achetée une seule fois, avec un coût en objets et un effet permanent :
  - [Barricade] : coûte [2 conserves + 1 bouteille d'eau] -> [+1 cœur] au héros.
  - [Atelier] : coûte [2 piles + 1 conserve] -> la batte fait [+1 dégât].
  - [Lampe renforcée] : coûte [2 piles] -> faisceau de lampe [+40 %] de portée.
- Coûts et effets dans data/reglages.gd (Eliott doit pouvoir les changer).
- Sur l'écran Base : une carte par construction (nom, coût avec icônes, effet en une phrase, bouton "Construire" actif seulement si on a assez d'objets, "Construit" sinon). La construction faite apparaît dans le dessin de la base.
- Les effets s'appliquent dans le niveau (cœurs, dégâts, lampe). Sauvegardés.
- La fiole de remède ne sert à aucune construction (elle servira au remède, étape e).
```

## Étape L2-c : la carte

```
Lot 2, étape (c) : la CARTE.
- Enchaînement : Base -> bouton "Partir" -> Carte -> choix d'un lieu -> lieu -> fin -> Base.
- La carte est un écran dessiné (plan de ville la nuit, style du jeu) avec 2 lieux : le Supermarché (disponible) et [la Maison] (affichée "Bientôt", non cliquable jusqu'à l'étape d).
- Toucher un lieu affiche une fiche : nom, danger (nombre de zombies), objets à trouver, bouton "Y aller". Bouton "Retour" vers la base.
- Prépare le multi-lieux proprement : sépare la logique générique du niveau (scripts/niveau.gd) du contenu du supermarché (scène de lieu), et l'autoload Partie retient le lieu choisi. Le supermarché doit rester identique à jouer.
```

## Étape L2-d : le deuxième lieu, la maison

```
Lot 2, étape (d) : un deuxième lieu jouable, [la MAISON abandonnée].
- Plus petite que le supermarché, plusieurs pièces reliées par des portes ouvertes (murs), [2 zombies lents + 1 rapide].
- 3 cachettes avec de nouveaux styles dessinés en formes simples : [armoire, dessous de lit, baignoire]. Même règles que les cachettes existantes.
- [5] objets à ramasser, une sortie (porte d'entrée), même ambiance nuit + lampe + brouillard.
- Débloque la Maison sur la carte.
- Réutilise les scènes existantes (Mur, Cachette, Objet, Zombie, Sortie, HUD) ; ajoute des styles plutôt que de nouvelles scènes quand c'est possible.
- Garde les valeurs d'équilibrage dans data/reglages.gd.
```

## Étape L2-e : objectifs de mission et remède

```
Lot 2, étape (e) : OBJECTIFS et REMÈDE.
- Chaque lieu a un objectif affiché sur sa fiche de la carte et en haut de l'écran pendant la mission : Supermarché = [rapporter la fiole de remède], Maison = [rapporter 2 bandages].
- Objectif rempli en sortant vivant : écran de fin "Mission réussie !" avec un bonus [1 objet au hasard en plus].
- Jauge du remède sur l'écran Base : chaque fiole rapportée remplit la jauge. À [3] fioles : écran "Remède trouvé !" (fin du lot 2), puis on peut continuer à jouer.
- Les fioles utilisées pour le remède ne sont plus dans l'inventaire. Nombres dans data/reglages.gd. Sauvegardé.
```
